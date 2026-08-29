import SwiftUI
import AppKit

/// Sección «Perfiles»: qué cambia Gluffi según dónde estés dictando.
///
/// La lista y el detalle van en la misma pantalla, no en dos ventanas: el orden
/// **es** la prioridad, así que hay que poder ver la lista mientras se edita un
/// perfil para entender por qué gana uno u otro.
struct ProfilesView: View {

    @ObservedObject private var store = ProfileStore.shared
    @State private var selection: UUID?
    @State private var showingPicker = false
    private let instaladas: InstalledApps = SystemInstalledApps()

    private var selected: Profile? { selection.flatMap { store.profile(with: $0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gluffi aplica el primer perfil cuya lista incluya la aplicación donde vas a dictar. Arrastra para cambiar la prioridad: gana el de más arriba.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            lista

            if let perfil = selected {
                Divider()
                detalle(perfil)
            } else if !store.profiles.isEmpty {
                Text("Elige un perfil para ver qué cambia.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
    }

    // MARK: - Lista

    private var lista: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.profiles.isEmpty {
                Text("Todavía no hay perfiles. Sin ninguno, Gluffi usa tus preferencias en todas las aplicaciones.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                List {
                    ForEach(store.profiles) { perfil in fila(perfil) }
                        .onMove { origen, destino in
                            store.move(fromOffsets: origen, toOffset: destino)
                        }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(store.profiles.count) * 34 + 8, 150))
            }

            Button {
                let nuevo = Profile(name: "Perfil nuevo", bundleIDs: [],
                                    order: store.profiles.count)
                store.add(nuevo)
                selection = nuevo.id
            } label: {
                Label("Añadir perfil", systemImage: "plus")
            }
            .controlSize(.small)
        }
    }

    private func fila(_ perfil: Profile) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(perfil.name).font(.system(size: 12.5))
                Text(resumen(perfil))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            // Desactivar no es borrar: saca al perfil de la resolución y lo
            // conserva, que es lo que hace falta para probar si era el culpable.
            Toggle("", isOn: Binding(
                get: { perfil.isActive },
                set: { nuevo in
                    var copia = perfil
                    copia.isActive = nuevo
                    store.update(copia)
                }))
                .labelsHidden()
                .controlSize(.mini)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { selection = perfil.id }
        .listRowBackground(selection == perfil.id
                           ? Theme.brand.opacity(0.14) : Color.clear)
    }

    private func resumen(_ perfil: Profile) -> String {
        let apps = perfil.bundleIDs.count
        let cambios = cuenta(perfil.overrides)
        let parteApps = apps == 0 ? "Sin aplicaciones"
                                  : (apps == 1 ? "1 aplicación" : "\(apps) aplicaciones")
        let parteCambios = cambios == 0 ? "sin cambios"
                                        : (cambios == 1 ? "1 cambio" : "\(cambios) cambios")
        return "\(parteApps) · \(parteCambios)"
    }

    private func cuenta(_ o: ProfileOverrides) -> Int {
        var n = 0
        if o.cleanupLevel != nil { n += 1 }
        if o.spellFix != nil { n += 1 }
        if o.initialCapital != nil { n += 1 }
        if o.trailingPeriod != nil { n += 1 }
        if o.dictionary != nil { n += 1 }
        if o.snippets != nil { n += 1 }
        if o.language != nil { n += 1 }
        if o.model != nil { n += 1 }
        if o.systemPolish != nil { n += 1 }
        return n
    }

    // MARK: - Detalle

    @ViewBuilder
    private func detalle(_ perfil: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Nombre", text: enlace(perfil, \.name))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Spacer()
                Button(role: .destructive) {
                    store.remove(perfil.id)
                    selection = nil
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .controlSize(.small)
            }

            apps(perfil)
            Divider()
            sobrescrituras(perfil)
        }
    }

    private func apps(_ perfil: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aplicaciones")
                .font(.system(size: 12, weight: .medium))
            if perfil.bundleIDs.isEmpty {
                Text("Ninguna todavía. Un perfil sin aplicaciones no se aplica nunca.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                FlowRow(perfil.bundleIDs) { bundleID in
                    etiqueta(bundleID, en: perfil)
                }
                if perfil.bundleIDs.contains(where: { !instaladas.isInstalled($0) }) {
                    // Las que no tienes se quedan: el día que instales Slack, el
                    // perfil ya lo estaba esperando. Un identificador que no casa
                    // con nada no hace daño.
                    Text("En gris, las que no tienes instaladas. Se quedan por si las instalas.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            Button {
                showingPicker = true
            } label: {
                Label("Añadir aplicaciones…", systemImage: "plus")
            }
            .controlSize(.small)
            .popover(isPresented: $showingPicker) {
                ProfilesAppPicker(selected: enlace(perfil, \.bundleIDs)) {
                    showingPicker = false
                }
            }
        }
    }

    /// Una app del perfil. Las ausentes se enseñan igual, en gris: quitarlas de
    /// la vista escondería que el perfil ya las cubre.
    private func etiqueta(_ bundleID: String, en perfil: Profile) -> some View {
        let presente = instaladas.isInstalled(bundleID)
        return HStack(spacing: 4) {
            Text(nombreDe(bundleID))
                .font(.system(size: 11))
                .foregroundStyle(presente ? .primary : .tertiary)
            Button {
                var copia = perfil
                copia.bundleIDs.removeAll { $0 == bundleID }
                store.update(copia)
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(presente ? 0.08 : 0.035)))
    }

    private func sobrescrituras(_ perfil: Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Qué cambia en esas aplicaciones")
                .font(.system(size: 12, weight: .medium))
            Text("Lo que dejes en «Heredar» sigue tus preferencias generales. Un perfil con todo heredado no cambia nada.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            triEstado("Mayúscula inicial", enlaceOpt(perfil, \.initialCapital),
                      si: "Sí", no: "No")
            triEstado("Punto final", enlaceOpt(perfil, \.trailingPeriod),
                      si: "Conservar", no: "Quitar")
            triEstado("Corrector ortográfico", enlaceOpt(perfil, \.spellFix),
                      si: "Activo", no: "Inactivo")
            triEstado("Diccionario", enlaceOpt(perfil, \.dictionary),
                      si: "Activo", no: "Inactivo")
            triEstado("Snippets", enlaceOpt(perfil, \.snippets),
                      si: "Activos", no: "Inactivos")
            triEstado("Repaso con el modelo de macOS", enlaceOpt(perfil, \.systemPolish),
                      si: "Activo", no: "Inactivo")

            limpieza(perfil)
            idioma(perfil)
            modelo(perfil)
        }
    }

    /// Tres estados, y «Heredar» es el primero porque es el valor por defecto y
    /// el que deja el perfil sin efecto.
    private func triEstado(_ titulo: String, _ valor: Binding<Bool?>,
                           si: String, no: String) -> some View {
        HStack {
            Text(titulo).font(.system(size: 12))
            Spacer()
            Picker("", selection: Binding(
                get: { valor.wrappedValue.map { $0 ? 1 : 2 } ?? 0 },
                set: { valor.wrappedValue = $0 == 0 ? nil : ($0 == 1) })) {
                Text("Heredar").tag(0)
                Text(si).tag(1)
                Text(no).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
        }
    }

    private func limpieza(_ perfil: Profile) -> some View {
        HStack {
            Text("Limpieza del dictado").font(.system(size: 12))
            Spacer()
            Picker("", selection: Binding(
                get: { perfil.overrides.cleanupLevel?.rawValue ?? "" },
                set: { nuevo in
                    var copia = perfil
                    copia.overrides.cleanupLevel = nuevo.isEmpty ? nil
                                                                 : CleanupLevel(rawValue: nuevo)
                    store.update(copia)
                })) {
                Text("Heredar").tag("")
                ForEach(CleanupLevel.allCases, id: \.rawValue) { nivel in
                    Text(nivel.titulo).tag(nivel.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 260)
        }
    }

    private func idioma(_ perfil: Profile) -> some View {
        HStack {
            Text("Idioma").font(.system(size: 12))
            Spacer()
            Picker("", selection: Binding(
                get: { perfil.overrides.language ?? "" },
                set: { nuevo in
                    var copia = perfil
                    copia.overrides.language = nuevo.isEmpty ? nil : nuevo
                    store.update(copia)
                })) {
                Text("Heredar").tag("")
                ForEach(["es", "en", "fr", "pt", "de", "it"], id: \.self) { codigo in
                    Text(Config.languageName(for: codigo)).tag(codigo)
                }
            }
            .labelsHidden()
            .frame(width: 260)
        }
    }

    /// Solo se ofrecen los modelos **descargados**. Elegir uno ausente dejaría
    /// una sobrescritura que no hace nada, y el usuario no tendría forma de
    /// saberlo: el dictado saldría bien, con el modelo global, y él creería que
    /// está usando otro.
    private func modelo(_ perfil: Profile) -> some View {
        let instalados = VoiceModel.installed(in: ModelDownloader.destinationDirectory)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Modelo de voz").font(.system(size: 12))
                Spacer()
                Picker("", selection: Binding(
                    get: { perfil.overrides.model ?? "" },
                    set: { nuevo in
                        var copia = perfil
                        copia.overrides.model = nuevo.isEmpty ? nil : nuevo
                        store.update(copia)
                    })) {
                    Text("Heredar").tag("")
                    ForEach(instalados) { modelo in
                        Text("\(modelo.title) · \(ModelDownloader.humanSize(modelo.bytes))")
                            .tag(modelo.id)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
                .disabled(instalados.isEmpty)
            }
            Text(instalados.count > 1
                 ? "Un modelo más liviano transcribe mucho antes. En un dictado corto la carga del modelo es casi todo el tiempo de espera."
                 : "Solo tienes un modelo descargado. Baja otro desde Configuración para poder cambiarlo por aplicación.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Enlaces al store

    private func enlace<T>(_ perfil: Profile,
                           _ campo: WritableKeyPath<Profile, T>) -> Binding<T> {
        Binding(
            get: { store.profile(with: perfil.id)?[keyPath: campo] ?? perfil[keyPath: campo] },
            set: { nuevo in
                guard var copia = store.profile(with: perfil.id) else { return }
                copia[keyPath: campo] = nuevo
                store.update(copia)
            })
    }

    private func enlaceOpt(_ perfil: Profile,
                           _ campo: WritableKeyPath<ProfileOverrides, Bool?>) -> Binding<Bool?> {
        Binding(
            get: { store.profile(with: perfil.id)?.overrides[keyPath: campo] ?? nil },
            set: { nuevo in
                guard var copia = store.profile(with: perfil.id) else { return }
                copia.overrides[keyPath: campo] = nuevo
                store.update(copia)
            })
    }

    /// El nombre visible de una app. El del sistema si está instalada; si no, el
    /// de nuestro catálogo. El identificador crudo solo como último recurso, para
    /// una app que el usuario añadió y luego desinstaló.
    private func nombreDe(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let nombre = FileManager.default.displayName(atPath: url.path)
            return nombre.hasSuffix(".app") ? String(nombre.dropLast(4)) : nombre
        }
        return KnownApps.name(for: bundleID) ?? bundleID
    }
}

/// Filas que se rompen solas. Las apps de un perfil son etiquetas de ancho
/// variable y un `HStack` las sacaría del panel.
struct FlowRow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(filas().enumerated()), id: \.offset) { _, fila in
                HStack(spacing: 5) {
                    ForEach(fila, id: \.self) { content($0) }
                }
            }
        }
    }

    /// Tres por fila. Un cálculo de ancho real exigiría medir cada etiqueta, y
    /// para una lista de aplicaciones no compensa.
    private func filas() -> [[Item]] {
        stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }
    }
}
