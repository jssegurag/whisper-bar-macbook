import SwiftUI

/// Sección General de Preferencias.
///
/// Se reescribió sin `Form`: el layout de etiqueta y valor de `Form` pedía más
/// ancho del que tiene la ventana, comprimía la barra lateral y le recortaba los
/// iconos. Ahora usa el mismo patrón que las demás secciones —etiqueta, control,
/// descripción debajo— con el ancho acotado.
struct GeneralTab: View {

    @State private var language: String
    @State private var minDuration: Double
    @State private var pillEnabled: Bool
    @State private var launchAtLogin: Bool
    @State private var launchError: String?

    private let languages = [
        ("es", "Español"), ("en", "English"), ("fr", "Français"),
        ("pt", "Português"), ("de", "Deutsch"), ("it", "Italiano"),
        ("auto", "Detectar solo"),
    ]

    init() {
        _language      = State(initialValue: Config.shared.language)
        _minDuration   = State(initialValue: Config.shared.minRecordingDuration)
        _pillEnabled   = State(initialValue: Config.shared.floatingPillEnabled)
        _launchAtLogin = State(initialValue: LaunchAtLogin.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            setting("Idioma") {
                Picker("", selection: $language) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
                .onChange(of: language) { Config.shared.language = $0 }
            } description: {
                Text("El idioma en el que hablas. «Detectar solo» acierta menos y tarda algo más.")
            }

            // El nombre importa: «duración mínima de grabación» describe el
            // mecanismo; esto describe para qué sirve.
            setting("Ignorar grabaciones muy cortas") {
                HStack(spacing: 10) {
                    Slider(value: $minDuration, in: 0.2...1.5, step: 0.1)
                        .frame(width: 200)
                        .onChange(of: minDuration) { Config.shared.minRecordingDuration = $0 }
                    Text(String(format: "%.1f s", minDuration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 46, alignment: .leading)
                }
            } description: {
                Text("Un roce del atajo no dispara una transcripción vacía.")
            }

            Divider()

            setting(nil) {
                Toggle("Mostrar la píldora flotante", isOn: $pillEnabled)
                    .onChange(of: pillEnabled) { newValue in
                        Config.shared.floatingPillEnabled = newValue
                        if newValue { PillWindowController.shared.showPill() }
                        else        { PillWindowController.shared.hidePill() }
                    }
            } description: {
                Text("Un clic graba, otro transcribe. Se arrastra para moverla.")
            }

            setting(nil) {
                Toggle("Abrir Gluffi al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        // Se informa el error en vez de dejar el interruptor
                        // mintiendo: el caso más común es que la app no esté en
                        // una carpeta de aplicaciones.
                        launchError = LaunchAtLogin.set(newValue)
                        if launchError != nil { launchAtLogin = LaunchAtLogin.isEnabled }
                    }
            } description: {
                if let launchError {
                    Text(launchError).foregroundStyle(Theme.warn)
                } else {
                    Text("Una app de barra de menú que hay que abrir a mano se deja de usar.")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    /// Etiqueta opcional, control, y descripción debajo con el ancho acotado para
    /// que ninguna frase empuje el layout.
    private func setting<Control: View, Description: View>(
        _ label: String?,
        @ViewBuilder control: () -> Control,
        @ViewBuilder description: () -> Description) -> some View {

        VStack(alignment: .leading, spacing: 5) {
            if let label {
                Text(label).font(.system(size: 13))
            }
            control()
            description()
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420, alignment: .leading)
        }
    }
}
