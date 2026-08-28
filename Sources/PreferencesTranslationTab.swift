import SwiftUI

/// Pestaña de traducción.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Traducción

struct TranslationTab: View {
    @State private var enabled: Bool
    @State private var targetLang: String

    private let targetLanguages = [
        ("en", "English"), ("es", "Español"), ("fr", "Français"),
        ("pt", "Português"), ("de", "Deutsch"), ("it", "Italiano"),
        ("ja", "日本語"), ("zh", "中文"), ("ko", "한국어"),
    ]

    init() {
        _enabled    = State(initialValue: Config.shared.translationEnabled)
        _targetLang = State(initialValue: Config.shared.translationTargetLanguage)
    }

    var body: some View {
        Form {
            Toggle("Activar traducción por voz", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    Config.shared.translationEnabled = newValue
                }

            Picker("Idioma destino:", selection: $targetLang) {
                ForEach(targetLanguages, id: \.0) { code, name in
                    Text("\(name) (\(code))").tag(code)
                }
            }
            .onChange(of: targetLang) { newValue in
                Config.shared.translationTargetLanguage = newValue
            }
            .disabled(!enabled)

            if targetLang == "en" {
                Text("✅ Usa whisper-cli -tr (rápido, sin LLM)")
                    .foregroundColor(.secondary).font(.caption)
            } else {
                Text("⚠️ Requiere LLM activado para traducir via llama-completion")
                    .foregroundColor(.orange).font(.caption)
            }

            HStack {
                Text("Atajo:")
                Spacer()
                Text("⌘ ⌥ ⇧")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15)))
            }
        }
        .padding()
    }
}
