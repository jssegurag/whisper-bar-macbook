import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelsTab()
                .tabItem { Label("Modelos", systemImage: "cpu") }
            LLMTab()
                .tabItem { Label("Corrección LLM", systemImage: "wand.and.stars") }
            TranslationTab()
                .tabItem { Label("Traducción", systemImage: "globe") }
            VoiceActionsTab()
                .tabItem { Label("Acciones", systemImage: "bolt.fill") }
            StreamingTab()
                .tabItem { Label("Streaming", systemImage: "waveform.circle") }
            DictionaryTab()
                .tabItem { Label("Diccionario", systemImage: "character.book.closed") }
            AudioTab()
                .tabItem { Label("Audio", systemImage: "waveform") }
            ShortcutsTab()
                .tabItem { Label("Atajos", systemImage: "command") }
        }
        .frame(width: 580, height: 460)
        .padding()
    }
}

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

// MARK: - Modelos

struct ModelsTab: View {
    @State private var whisperPath: String
    @State private var modelPath: String
    @ObservedObject private var updater = UpdateChecker.shared

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

                UpdateRow(
                    packageName: "whisper-cpp",
                    state: updater.whisperState,
                    onUpdate: { updater.upgradeWhisper() },
                    onCheck:  { updater.checkForUpdates(force: true) }
                )
            }
        }
        .padding()
        .onAppear { updater.checkForUpdates() }
    }
}

// MARK: - LLM (Corrección)

struct LLMTab: View {
    @State private var enabled: Bool
    @State private var llmCliPath: String
    @State private var llmModelPath: String
    @State private var llmPrompt: String
    @ObservedObject private var updater = UpdateChecker.shared

    init() {
        _enabled      = State(initialValue: Config.shared.llmEnabled)
        _llmCliPath   = State(initialValue: Config.shared.llmCliPath)
        _llmModelPath = State(initialValue: Config.shared.llmModelPath)
        _llmPrompt    = State(initialValue: Config.shared.llmPrompt)
    }

    var body: some View {
        Form {
            Toggle("Activar corrección con LLM", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    Config.shared.llmEnabled = newValue
                }

            Text("Cuando está activado, las transcripciones se procesan con un modelo local (llama-completion) para corregir ortografía y puntuación. Si está desactivado, el texto se pega tal como lo devolvió Whisper.")
                .foregroundColor(.secondary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Section("Configuración del modelo") {
                PathField(
                    label: "llama-completion:",
                    path: $llmCliPath,
                    isValid: FileManager.default.isExecutableFile(atPath: llmCliPath)
                )
                .onChange(of: llmCliPath) { newValue in
                    Config.shared.llmCliPath = newValue
                }

                PathField(
                    label: "Modelo .gguf:",
                    path: $llmModelPath,
                    isValid: !llmModelPath.isEmpty && FileManager.default.fileExists(atPath: llmModelPath)
                )
                .onChange(of: llmModelPath) { newValue in
                    Config.shared.llmModelPath = newValue
                }

                if llmModelPath.isEmpty {
                    Text("⚠️ Sin modelo configurado — la corrección con LLM no se aplicará aunque esté activada.")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                UpdateRow(
                    packageName: "llama.cpp",
                    state: updater.llamaState,
                    onUpdate: { updater.upgradeLlama() },
                    onCheck:  { updater.checkForUpdates(force: true) }
                )
            }
            .disabled(!enabled)

            Section("Prompt del sistema") {
                TextEditor(text: $llmPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                    .onChange(of: llmPrompt) { newValue in
                        Config.shared.llmPrompt = newValue
                    }
            }
            .disabled(!enabled)
        }
        .padding()
        .onAppear { updater.checkForUpdates() }
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

// MARK: - Acciones por voz

struct VoiceActionsTab: View {
    @State private var enabled: Bool

    init() {
        _enabled = State(initialValue: Config.shared.voiceActionsEnabled)
    }

    var body: some View {
        Form {
            Toggle("Activar acciones por voz", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    Config.shared.voiceActionsEnabled = newValue
                }

            Text("Requiere LLM activado para detectar comandos.")
                .foregroundColor(.secondary).font(.caption)

            Section("Comandos disponibles") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\"Busca en Google...\" → abre búsqueda web", systemImage: "magnifyingglass")
                    Label("\"Crea recordatorio...\" → crea en Reminders", systemImage: "bell")
                    Label("\"Abre Safari/Terminal...\" → abre aplicación", systemImage: "app")
                    Label("\"Traduce al francés lo último\" → retraduce", systemImage: "globe")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Text("Si no se detecta ningún comando, el texto se pega normalmente.")
                .foregroundColor(.secondary).font(.caption).italic()
        }
        .padding()
    }
}

// MARK: - Audio Feedback

struct AudioTab: View {
    @State private var feedbackEnabled: Bool
    @State private var feedbackVolume: Double
    @State private var selectedPresetId: String
    @State private var customPath: String
    @State private var selectedCategory: String = "Todos"

    // Instancia local solo para previsualizaciones
    private let previewFeedback = AudioFeedback()

    private let categories = ["Todos"] + AudioPreset.categories + ["Personalizado"]

    init() {
        _feedbackEnabled   = State(initialValue: Config.shared.audioFeedbackEnabled)
        _feedbackVolume    = State(initialValue: Config.shared.audioFeedbackVolume)
        _selectedPresetId  = State(initialValue: Config.shared.audioFeedbackPreset)
        _customPath        = State(initialValue: Config.shared.audioFeedbackCustomPath)
    }

    private var visiblePresets: [AudioPreset] {
        switch selectedCategory {
        case "Todos":         return AudioPreset.all
        case "Personalizado": return []
        default:              return AudioPreset.all.filter { $0.category == selectedCategory }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Toggle + Volumen ─────────────────────────────────────────────
            Form {
                Toggle("Reproducir sonido mientras transcribe", isOn: $feedbackEnabled)
                    .onChange(of: feedbackEnabled) { Config.shared.audioFeedbackEnabled = $0 }

                HStack {
                    Image(systemName: "speaker.fill").foregroundColor(.secondary)
                    Slider(value: $feedbackVolume, in: 0.0...1.0, step: 0.05)
                        .disabled(!feedbackEnabled)
                    Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
                    Text("\(Int(feedbackVolume * 100))%")
                        .monospacedDigit().frame(width: 36, alignment: .trailing)
                }
                .onChange(of: feedbackVolume) { Config.shared.audioFeedbackVolume = $0 }
                .opacity(feedbackEnabled ? 1 : 0.4)
            }
            .frame(height: 90)

            Divider().padding(.horizontal)

            // ── Selector de categoría ────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button(cat) { selectedCategory = cat }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedCategory == cat
                                          ? Color.accentColor
                                          : Color.secondary.opacity(0.15))
                            )
                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                            .font(.system(.caption, weight: .medium))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            Divider().padding(.horizontal)

            // ── Lista de presets ─────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(visiblePresets) { preset in
                        PresetRow(
                            preset: preset,
                            isSelected: selectedPresetId == preset.id,
                            onSelect: {
                                selectedPresetId = preset.id
                                Config.shared.audioFeedbackPreset = preset.id
                            },
                            onPreview: {
                                previewFeedback.preview(
                                    presetId: preset.id,
                                    volume: Float(feedbackVolume)
                                )
                            }
                        )
                    }

                    // ── Archivo personalizado ────────────────────────────────
                    if selectedCategory == "Todos" || selectedCategory == "Personalizado" {
                        Divider().padding(.vertical, 4)
                        CustomFileRow(
                            customPath: $customPath,
                            isSelected: selectedPresetId == "custom",
                            volume: Float(feedbackVolume),
                            previewFeedback: previewFeedback,
                            onSelect: {
                                selectedPresetId = "custom"
                                Config.shared.audioFeedbackPreset = "custom"
                            }
                        )
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }

            Divider().padding(.horizontal)

            // ── Dispositivo de entrada ───────────────────────────────────────
            HStack {
                Image(systemName: "mic").foregroundColor(.secondary)
                Text("Dispositivo de entrada: Default del sistema")
                    .foregroundColor(.secondary).font(.caption)
                Spacer()
                Text("(próximamente)").foregroundColor(.secondary).font(.caption).italic()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }
}

// MARK: - Fila de preset

private struct PresetRow: View {
    let preset: AudioPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    Text(preset.category)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColor(preset.category).opacity(0.18)))
                        .foregroundColor(categoryColor(preset.category))
                }
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onPreview()
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Previsualizar 3 segundos")
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Relajante":     return .blue
        case "Concentración": return .purple
        case "Energético":    return .orange
        default:              return .gray
        }
    }
}

// MARK: - Fila de archivo personalizado

private struct CustomFileRow: View {
    @Binding var customPath: String
    let isSelected: Bool
    let volume: Float
    let previewFeedback: AudioFeedback
    let onSelect: () -> Void

    private var fileName: String {
        customPath.isEmpty ? "Ningún archivo seleccionado" : URL(fileURLWithPath: customPath).lastPathComponent
    }
    private var isValid: Bool {
        !customPath.isEmpty && FileManager.default.fileExists(atPath: customPath)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { if isValid { onSelect() } }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Archivo personalizado")
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    Text("Personalizado")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.18)))
                        .foregroundColor(.gray)
                }
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(isValid ? .secondary : .orange)
            }

            Spacer()

            if isValid {
                Button {
                    previewFeedback.preview(presetId: "custom", volume: volume)
                } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Previsualizar 3 segundos")
            }

            Button("Elegir…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
                if panel.runModal() == .OK, let url = panel.url {
                    customPath = url.path
                    Config.shared.audioFeedbackCustomPath = url.path
                    onSelect()
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { if isValid { onSelect() } }
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
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para transcribir y pegar.")
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()

            HStack {
                Text("Traducir:")
                Spacer()
                Text("⌘ ⌥ ⇧")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para traducir.")
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()

            HStack {
                Text("Transcripción en vivo:")
                Spacer()
                Text("⌘ ⌥ ⌃")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Presiona para toggle del panel flotante con streaming en tiempo real.")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
    }
}

// MARK: - Componente de actualización

struct UpdateRow: View {
    let packageName: String
    let state: UpdateChecker.PackageState
    let onUpdate: () -> Void
    let onCheck: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusContent
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch state {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary)
                Text(packageName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .checking:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.65)
                Text("Verificando \(packageName)…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(packageName) al día")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .available(let version):
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.orange)
                Text("Actualización disponible: \(version)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        case .upgrading:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.65)
                Text("Actualizando \(packageName)…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .upgraded:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(packageName) actualizado correctamente")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .available:
            Button("Actualizar") { onUpdate() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
        case .checking, .upgrading:
            EmptyView()
        default:
            Button("Verificar") { onCheck() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
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
