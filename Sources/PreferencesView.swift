import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelsTab()
                .tabItem { Label("Modelos", systemImage: "cpu") }
            StreamingTab()
                .tabItem { Label("Streaming", systemImage: "waveform.circle") }
            AudioTab()
                .tabItem { Label("Audio", systemImage: "waveform") }
            ShortcutsTab()
                .tabItem { Label("Atajos", systemImage: "command") }
        }
        .frame(width: 560, height: 420)
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

// MARK: - Streaming

struct StreamingTab: View {
    @State private var streamPath: String
    @State private var stepMs: Double
    @State private var lengthMs: Double
    @State private var keepMs: Double

    init() {
        _streamPath = State(initialValue: Config.shared.whisperStreamPath)
        _stepMs     = State(initialValue: Double(Config.shared.streamStepMs))
        _lengthMs   = State(initialValue: Double(Config.shared.streamLengthMs))
        _keepMs     = State(initialValue: Double(Config.shared.streamKeepMs))
    }

    var body: some View {
        Form {
            Section("Transcripción en Tiempo Real") {
                PathField(label: "whisper-stream:", path: $streamPath,
                          isValid: FileManager.default.isExecutableFile(atPath: streamPath))
                    .onChange(of: streamPath) { newValue in
                        Config.shared.whisperStreamPath = newValue
                    }

                Text("Panel flotante con transcripción en vivo usando whisper-stream.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Parámetros de Streaming") {
                HStack {
                    Text("Step (ms):")
                    Slider(value: $stepMs, in: 1000...10000, step: 500)
                    Text("\(Int(stepMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: stepMs) { newValue in
                    Config.shared.streamStepMs = Int(newValue)
                }

                HStack {
                    Text("Length (ms):")
                    Slider(value: $lengthMs, in: 5000...30000, step: 1000)
                    Text("\(Int(lengthMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: lengthMs) { newValue in
                    Config.shared.streamLengthMs = Int(newValue)
                }

                HStack {
                    Text("Keep (ms):")
                    Slider(value: $keepMs, in: 0...2000, step: 100)
                    Text("\(Int(keepMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: keepMs) { newValue in
                    Config.shared.streamKeepMs = Int(newValue)
                }

                Text("Step: frecuencia de output. Length: ventana de audio. Keep: overlap entre chunks.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}

// MARK: - Atajos

struct ShortcutsTab: View {
    var body: some View {
        Form {
            HStack {
                Text("Transcripción:")
                Spacer()
                Text("⌘ ⌥")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para transcribir y pegar.")
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()

            HStack {
                Text("Transcripción en vivo:")
                Spacer()
                Text("⌘ ⌥ ⌃")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Presiona para toggle del panel flotante con streaming en tiempo real.")
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
