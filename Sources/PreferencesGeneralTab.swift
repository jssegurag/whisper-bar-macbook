import SwiftUI

/// Pestaña General de Preferencias.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - General

struct GeneralTab: View {
    @State private var language: String
    @State private var minDuration: Double
    @State private var pillEnabled: Bool

    private let languages = [
        ("es", "Español"), ("en", "English"), ("fr", "Français"),
        ("pt", "Português"), ("de", "Deutsch"), ("it", "Italiano"),
        ("auto", "Auto-detectar"),
    ]

    init() {
        _language    = State(initialValue: Config.shared.language)
        _minDuration = State(initialValue: Config.shared.minRecordingDuration)
        _pillEnabled = State(initialValue: Config.shared.floatingPillEnabled)
    }

    var body: some View {
        Form {
            Picker("Idioma de transcripción:", selection: $language) {
                ForEach(languages, id: \.0) { code, name in
                    Text("\(name) (\(code))").tag(code)
                }
            }
            .onChange(of: language) { newValue in
                Config.shared.language = newValue
            }

            HStack {
                Text("Duración mínima de grabación:")
                Slider(value: $minDuration, in: 0.2...3.0, step: 0.1)
                Text(String(format: "%.1fs", minDuration))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            .onChange(of: minDuration) { newValue in
                Config.shared.minRecordingDuration = newValue
            }

            Divider()

            Section {
                Toggle("Mostrar pill flotante de micrófono", isOn: $pillEnabled)
                    .onChange(of: pillEnabled) { newValue in
                        Config.shared.floatingPillEnabled = newValue
                        if newValue { PillWindowController.shared.showPill() }
                        else        { PillWindowController.shared.hidePill() }
                    }
                Text("Click para grabar, click de nuevo para transcribir. Arrastra para reposicionar.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}
