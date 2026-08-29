import SwiftUI
import AppKit
import UserNotifications
import ApplicationServices

/// Ventana de Configuración. Se hace una vez y no hace falta volver.
///
/// Recoge lo que estaba repartido y sin salida: las seis filas de diagnóstico del
/// menú, las rutas de binarios de cuatro pestañas de Preferencias, y los cuatro
/// diálogos de permisos que macOS lanzaba sin explicar para qué.
struct SetupView: View {

    @State private var summary = SetupSummary.current()
    @State private var lastChecked = Date()
    @StateObject private var downloader = ModelDownloader()
    @State private var installing: SetupComponent.Kind?
    @State private var message: String?
    @State private var keychainResult: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var notificationResult: String?
    @State private var accessibilityResult: String?

    var onDone: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            componentsCard
            permissions
            footer
        }
        .padding(24)
        .frame(width: 580)
        .tint(Theme.brand)
        .onChange(of: downloader.state) { state in
            if case .finished = state { refresh() }
        }
        .onAppear { readNotificationStatus() }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            GluffiMarkView(size: 34, color: Theme.brand)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.headline)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                Text(summary.subhead)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Text("Esto se configura una vez. Después no hace falta volver aquí: si algo se rompe, Gluffi te avisa y te trae directo a esta ventana.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Los cuatro componentes

    private var componentsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(summary.components.enumerated()), id: \.element.id) { index, component in
                if index > 0 { Divider().opacity(0.5) }
                row(for: component)
            }
        }
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.07)))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func row(for component: SetupComponent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            badge(for: component.state)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(component.title).font(.system(size: 13.5, weight: .semibold))
                    Text(component.label)
                        .font(.system(size: 11))
                        .foregroundStyle(component.state == .missingRequired ? AnyShapeStyle(Theme.warn) : AnyShapeStyle(.tertiary))
                }
                Text(component.purpose)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(component.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                actions(for: component)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 15)
    }

    private func badge(for state: SetupComponent.State) -> some View {
        let fill: Color = state == .ready ? Theme.brand
                        : state == .missingRequired ? Theme.warn
                        : Color.white.opacity(0.14)
        let glyph = state == .ready ? "checkmark" : state == .missingRequired ? "exclamationmark" : "minus"
        return ZStack {
            Circle().fill(fill)
            Image(systemName: glyph)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(state == .missingOptional ? Color.white.opacity(0.5) : Theme.onBrand)
        }
        .frame(width: 18, height: 18)
    }

    @ViewBuilder
    private func actions(for component: SetupComponent) -> some View {
        switch component.kind {
        case .engine:
            VStack(alignment: .leading, spacing: 6) {
                // La comprobación de actualizaciones viaja con las rutas: aquí es
                // donde vive lo instalado, no en Preferencias.
                UpdateRow(packageName: "whisper-cpp",
                          state: UpdateChecker.shared.whisperState,
                          onUpdate: { UpdateChecker.shared.upgradeWhisper() },
                          onCheck: { UpdateChecker.shared.checkForUpdates(force: true) })
                engineButtons(component)
            }
        case .model:
            modelActions(component)
        case .streaming:
            HStack(spacing: 8) {
                if component.state != .ready {
                    Button("Instalar con Homebrew") { install("whisper-cpp", for: .streaming) }
                        .disabled(installing != nil)
                }
                Button("Cambiar…") { pickFile(for: .streaming) }
            }
        }
    }

    private func engineButtons(_ component: SetupComponent) -> some View {
        HStack(spacing: 8) {
            if component.state != .ready {
                Button("Instalar con Homebrew") { install("whisper-cpp", for: .engine) }
                    .buttonStyle(.borderedProminent)
                    .disabled(installing != nil)
            }
            Button("Cambiar…") { pickFile(for: .engine) }
        }
    }

    @ViewBuilder
    private func modelActions(_ component: SetupComponent) -> some View {
        switch downloader.state {
        case .downloading(let received, let total):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(received), total: Double(max(total, 1)))
                    .frame(width: 260)
                HStack(spacing: 8) {
                    Text("\(ModelDownloader.humanSize(received)) de \(ModelDownloader.humanSize(total))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Button("Cancelar") { downloader.cancel() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
        case .failed(let detail):
            VStack(alignment: .leading, spacing: 4) {
                Text("No se pudo descargar: \(detail)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.warn)
                Button("Reintentar") { downloader.start() }
            }
        default:
            HStack(spacing: 8) {
                if component.state != .ready {
                    Button("Descargar (\(ModelDownloader.humanSize(ModelDownloader.defaultModel.bytes)))") {
                        downloader.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(component.state == .ready ? "Cambiar…" : "Elegir uno que ya tengo…") {
                    pickFile(for: .model)
                }
            }
        }
    }

    // MARK: - Permisos

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permisos del sistema")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)

            permissionRow(
                title: "Accesibilidad",
                purpose: accessibilityPurpose,
                action: ("Comprobar", { checkAccessibility() }))
            permissionRow(
                title: "Micrófono",
                purpose: "Para grabar tu voz.",
                action: ("Abrir Ajustes", { openPrivacyPane("Privacy_Microphone") }))
            permissionRow(
                title: "Notificaciones",
                purpose: notificationResult ?? notificationPurpose,
                action: notificationStatus == .authorized
                    ? ("Probar ahora", testNotification)
                    : ("Abrir Ajustes", { openNotificationSettings() }))
            permissionRow(
                title: "Llavero",
                purpose: keychainResult ?? "Solo si usas snippets sensibles. Se pide al insertar el primero.",
                action: ("Probar ahora", testKeychain))
        }
    }

    private func permissionRow(title: String, purpose: String,
                               action: (String, () -> Void)) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(purpose)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action.0) { action.1() }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.07)))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Pie

    private var footer: some View {
        HStack {
            if let message {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            } else {
                Text("Comprobado \(relativeCheck)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Comprobar de nuevo") { refresh() }
            Button("Listo") { onDone() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var relativeCheck: String {
        let elapsed = Date().timeIntervalSince(lastChecked)
        if elapsed < 60 { return "hace un momento" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.localizedString(for: lastChecked, relativeTo: Date())
    }

    // MARK: - Acciones

    private func refresh() {
        summary = SetupSummary.current()
        lastChecked = Date()
    }

    private func install(_ package: String, for kind: SetupComponent.Kind) {
        installing = kind
        message = "Instalando \(package) con Homebrew…"
        UpdateChecker.shared.install(package: package) { ok, output in
            installing = nil
            message = ok ? "\(package) instalado."
                         : "No se pudo instalar \(package). \(output.split(separator: "\n").last.map(String.init) ?? "")"
            refresh()
        }
    }

    private func pickFile(for kind: SetupComponent.Kind) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.message = {
            switch kind {
            case .engine:    return "Selecciona el binario whisper-cli"
            case .model:     return "Selecciona un modelo .bin de whisper"
            case .streaming: return "Selecciona el binario whisper-stream"
            }
        }()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch kind {
        case .engine:    Config.shared.whisperCliPath = url.path
        case .model:     Config.shared.modelPath = url.path
        case .streaming: Config.shared.whisperStreamPath = url.path
        }
        refresh()
    }

    private func openPrivacyPane(_ anchor: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        if let url { NSWorkspace.shared.open(url) }
    }

    /// Por qué existe esta fila: si el permiso está denegado, Gluffi avisa de los
    /// errores en notificaciones que nadie ve. Falla en silencio, y el usuario
    /// concluye que la app no avisa de nada.
    private var notificationPurpose: String {
        switch notificationStatus {
        case .authorized, .provisional:
            return "Para avisarte cuando algo falla, con el botón que lo arregla."
        case .denied:
            return "Están desactivadas. Sin ellas Gluffi no puede avisarte de un error: falla en silencio."
        default:
            return "Sin conceder todavía. Sin ellas Gluffi no puede avisarte de un error."
        }
    }

    /// Estado real, no el de la casilla de Ajustes.
    ///
    /// Con firma ad-hoc la entrada de permisos sobrevive por bundle identifier
    /// pero se ata al hash del binario. Tras recompilar, Ajustes puede seguir
    /// mostrando Gluffi marcada mientras el sistema deniega el permiso. La casilla
    /// miente; AXIsProcessTrusted() no.
    private var accessibilityPurpose: String {
        if let accessibilityResult { return accessibilityResult }
        return AXIsProcessTrusted()
            ? "Concedido. Para pegar el texto en la app donde estás escribiendo."
            : "NO concedido. Sin esto el texto se transcribe pero no se pega en ningún sitio."
    }

    private func checkAccessibility() {
        if AXIsProcessTrusted() {
            let destino = PasteTargetTracker.shared.currentTargetName ?? "ninguna app externa todavía"
            accessibilityResult = "Concedido. Ahora mismo pegaría en: \(destino)."
        } else {
            accessibilityResult = "NO concedido, aunque Ajustes muestre Gluffi marcada. "
                + "Pasa tras recompilar: el permiso se ata al binario y el binario cambió. "
                + "Quita Gluffi de la lista con el botón «−», vuelve a añadirla, y reinicia la app."
            openPrivacyPane("Privacy_Accessibility")
        }
    }

    private func readNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { notificationStatus = settings.authorizationStatus }
        }
    }

    /// Lanza una notificación de prueba real, con su botón. Es la única forma de
    /// comprobar de punta a punta que llegan.
    private func testNotification() {
        Notifier.shared.post(AppNotification.Content(
            title: "Las notificaciones funcionan",
            body: "Así se verán los avisos de Gluffi. Este trae un botón, como los de verdad.",
            actions: [.dismiss],
            identifier: "test"))
        notificationResult = "Enviada. Si no la ves, revísalas en Ajustes del Sistema."
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        readNotificationStatus()
    }

    /// Intenta tocar el Llavero. Sirve para reintentar tras un rebuild, que es
    /// cuando macOS vuelve a pedir permiso por el cambio de firma.
    private func testKeychain() {
        do {
            _ = try SecretBox.keychainBacked()
            keychainResult = "Llavero accesible. Los snippets sensibles funcionarán."
        } catch {
            keychainResult = "El Llavero rechazó el acceso: \(error.localizedDescription)"
        }
    }
}

/// El logo, dibujado desde el asset y recoloreado.
struct GluffiMarkView: View {
    let size: CGFloat
    var color: Color = Theme.brand

    var body: some View {
        Image(nsImage: MenuBarIcon.markTemplate())
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}
