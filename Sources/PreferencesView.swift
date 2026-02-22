import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelsTab()
                .tabItem { Label("Modelos", systemImage: "cpu") }
            TranslationTab()
                .tabItem { Label("Traducción", systemImage: "globe") }
            AudioTab()
                .tabItem { Label("Audio", systemImage: "waveform") }
            ShortcutsTab()
                .tabItem { Label("Atajos", systemImage: "command") }
        }
        .frame(width: 520, height: 400)
        .padding()
    }
}

// MARK: - General

struct GeneralTab: View {
    @State private var language: String
    @State private var minDuration: Double

    private let languages = [
        ("es", "Español"), ("en", "English"), ("fr", "Français"),
        ("pt", "Português"), ("de", "Deutsch"), ("it", "Italiano"),
        ("auto", "Auto-detectar"),
    ]

    init() {
        _language    = State(initialValue: Config.shared.language)
        _minDuration = State(initialValue: Config.shared.minRecordingDuration)
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
        }
        .padding()
    }
}

// MARK: - Modelos

struct ModelsTab: View {
    @State private var whisperPath: String
    @State private var modelPath: String

    init() {
        _whisperPath = State(initialValue: Config.shared.whisperCliPath)
        _modelPath   = State(initialValue: Config.shared.modelPath)
    }

    var body: some View {
        Form {
            Section("Whisper") {
                PathField(label: "whisper-cli:", path: $whisperPath,
                          isValid: FileManager.default.isExecutableFile(atPath: whisperPath))
                    .onChange(of: whisperPath) { newValue in
                        Config.shared.whisperCliPath = newValue
                    }

                PathField(label: "Modelo:", path: $modelPath,
                          isValid: FileManager.default.fileExists(atPath: modelPath))
                    .onChange(of: modelPath) { newValue in
                        Config.shared.modelPath = newValue
                    }
            }
        }
        .padding()
    }
}

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

// MARK: - Audio (placeholder)

struct AudioTab: View {
    var body: some View {
        Form {
            Text("Dispositivo de entrada: Default del sistema")
                .foregroundColor(.secondary)
            Text("Configuración de dispositivo estará disponible próximamente.")
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
    }
}

// MARK: - Atajos

struct ShortcutsTab: View {
    var body: some View {
        Form {
            HStack {
                Text("Transcribir:")
                Spacer()
                Text("⌘ ⌥")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            HStack {
                Text("Traducir:")
                Spacer()
                Text("⌘ ⌥ ⇧")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para procesar.")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
    }
}

// MARK: - Componente reutilizable

struct PathField: View {
    let label: String
    @Binding var path: String
    let isValid: Bool

    var body: some View {
        HStack {
            TextField(label, text: $path)
                .textFieldStyle(.roundedBorder)
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
            Button("Elegir…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    path = url.path
                }
            }
        }
    }
}
