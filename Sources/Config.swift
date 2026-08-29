import Foundation
import AppKit

/// Configuración centralizada via UserDefaults.
/// Las rutas se auto-detectan si no están configuradas explícitamente.
class Config {
    static let shared = Config()
    private let defaults = UserDefaults.standard

    // MARK: - Propiedades configurables

    /// Ruta al binario whisper-cli
    var whisperCliPath: String {
        get {
            if let saved = defaults.string(forKey: "whisperCliPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectWhisperCli() ?? "/opt/homebrew/bin/whisper-cli"
        }
        set { defaults.set(newValue, forKey: "whisperCliPath") }
    }

    /// Ruta al modelo .bin de Whisper
    var modelPath: String {
        get {
            if let saved = defaults.string(forKey: "modelPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectModel() ?? "\(NSHomeDirectory())/.whisper-realtime/ggml-large-v3.bin"
        }
        set { defaults.set(newValue, forKey: "modelPath") }
    }

    /// Código de idioma para la transcripción (es, en, fr, pt, auto…)
    var language: String {
        get { defaults.string(forKey: "language") ?? "es" }
        set { defaults.set(newValue, forKey: "language") }
    }

    /// Duración mínima de grabación en segundos (evita toques accidentales)
    var minRecordingDuration: TimeInterval {
        get {
            let v = defaults.double(forKey: "minRecordingDuration")
            return v > 0 ? v : 0.5
        }
        set { defaults.set(newValue, forKey: "minRecordingDuration") }
    }

    // MARK: - LLM Post-procesamiento

    /// Si el post-procesamiento con LLM está habilitado
    var llmEnabled: Bool {
        get { defaults.bool(forKey: "llmEnabled") }
        set { defaults.set(newValue, forKey: "llmEnabled") }
    }

    /// Ruta al binario llama-completion (single-shot, no modo conversación)
    var llmCliPath: String {
        get {
            if let saved = defaults.string(forKey: "llmCliPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectLlmCli() ?? "/opt/homebrew/bin/llama-completion"
        }
        set { defaults.set(newValue, forKey: "llmCliPath") }
    }

    /// Ruta al modelo LLM (.gguf)
    var llmModelPath: String {
        get {
            // Una ruta guardada que no es .gguf se ignora: sanea solo la
            // configuración de quien ya eligió el modelo equivocado, en vez de
            // dejarlo con un corrector que falla en cada dictado.
            if let saved = defaults.string(forKey: "llmModelPath"),
               Config.isGGUF(saved) {
                return saved
            }
            return Config.detectLlmModel() ?? ""
        }
        set { defaults.set(newValue, forKey: "llmModelPath") }
    }

    /// Prompt del sistema para corrección con LLM
    var llmPrompt: String {
        get {
            defaults.string(forKey: "llmPrompt")
                ?? "Corrige ortografía y puntuación del siguiente texto. No cambies las palabras, solo corrige errores. Devuelve SOLO el texto corregido."
        }
        set { defaults.set(newValue, forKey: "llmPrompt") }
    }

    // MARK: - Traducción por voz

    /// Si la traducción por voz está habilitada
    var translationEnabled: Bool {
        get { defaults.bool(forKey: "translationEnabled") }
        set { defaults.set(newValue, forKey: "translationEnabled") }
    }


    // MARK: - Acciones por voz

    /// Si las acciones por voz están habilitadas
    var voiceActionsEnabled: Bool {
        get { defaults.bool(forKey: "voiceActionsEnabled") }
        set { defaults.set(newValue, forKey: "voiceActionsEnabled") }
    }

    // MARK: - Pill flotante de micrófono

    /// Si el pill flotante (toggle de micrófono) está visible. Por defecto: true.
    var floatingPillEnabled: Bool {
        get { defaults.object(forKey: "floatingPillEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "floatingPillEnabled") }
    }

    /// Origen X del pill en la pantalla. .nan = sin valor previo (usar default).
    var floatingPillOriginX: Double {
        get { (defaults.object(forKey: "floatingPillOriginX") as? Double) ?? .nan }
        set { defaults.set(newValue, forKey: "floatingPillOriginX") }
    }

    /// Origen Y del pill en la pantalla. .nan = sin valor previo (usar default).
    var floatingPillOriginY: Double {
        get { (defaults.object(forKey: "floatingPillOriginY") as? Double) ?? .nan }
        set { defaults.set(newValue, forKey: "floatingPillOriginY") }
    }

    /// Nombre legible del idioma por código
    static func languageName(for code: String) -> String {
        let names = [
            "es": "Español", "en": "English", "fr": "Français",
            "pt": "Português", "de": "Deutsch", "it": "Italiano",
            "ja": "日本語", "zh": "中文", "ko": "한국語",
        ]
        return names[code] ?? code
    }

    // MARK: - Transcripción flotante / Streaming

    /// Ruta al binario whisper-stream
    var whisperStreamPath: String {
        get {
            if let saved = defaults.string(forKey: "whisperStreamPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectWhisperStream() ?? "/opt/homebrew/bin/whisper-stream"
        }
        set { defaults.set(newValue, forKey: "whisperStreamPath") }
    }

    var isWhisperStreamValid: Bool {
        FileManager.default.isExecutableFile(atPath: whisperStreamPath)
    }

    /// Step size en ms (cada cuánto whisper-stream produce output)
    var streamStepMs: Int {
        get {
            let v = defaults.integer(forKey: "streamStepMs")
            return v > 0 ? v : 3000
        }
        set { defaults.set(newValue, forKey: "streamStepMs") }
    }

    /// Longitud de audio para streaming en ms
    var streamLengthMs: Int {
        get {
            let v = defaults.integer(forKey: "streamLengthMs")
            return v > 0 ? v : 10000
        }
        set { defaults.set(newValue, forKey: "streamLengthMs") }
    }

    /// Overlap de audio para streaming en ms
    var streamKeepMs: Int {
        get {
            let v = defaults.integer(forKey: "streamKeepMs")
            return v > 0 ? v : 200
        }
        set { defaults.set(newValue, forKey: "streamKeepMs") }
    }

    /// Cantidad máxima de entradas en el historial
    var maxHistoryCount: Int {
        get {
            let v = defaults.integer(forKey: "maxHistoryCount")
            return v > 0 ? v : 100
        }
        set { defaults.set(newValue, forKey: "maxHistoryCount") }
    }

    // MARK: - Audio Feedback

    /// Si el sonido de feedback durante transcripción está habilitado
    var audioFeedbackEnabled: Bool {
        get { defaults.object(forKey: "audioFeedbackEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "audioFeedbackEnabled") }
    }

    /// Volumen del sonido de feedback (0.0 – 1.0). Default: 1.0
    var audioFeedbackVolume: Double {
        get {
            let v = defaults.double(forKey: "audioFeedbackVolume")
            return v > 0 ? v : 1.0
        }
        set { defaults.set(newValue, forKey: "audioFeedbackVolume") }
    }

    /// ID del preset de audio seleccionado (ver AudioPreset.all). Default: "theta"
    var audioFeedbackPreset: String {
        get { defaults.string(forKey: "audioFeedbackPreset") ?? "theta" }
        set { defaults.set(newValue, forKey: "audioFeedbackPreset") }
    }

    /// Ruta al archivo de audio personalizado (vacío = ninguno)
    var audioFeedbackCustomPath: String {
        get { defaults.string(forKey: "audioFeedbackCustomPath") ?? "" }
        set { defaults.set(newValue, forKey: "audioFeedbackCustomPath") }
    }

    // MARK: - Diccionario personalizado

    /// Si el diccionario personalizado se aplica a las transcripciones.
    /// Con el diccionario vacío es inerte, así que el default es true.
    var dictionaryEnabled: Bool {
        get { defaults.object(forKey: "dictionaryEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "dictionaryEnabled") }
    }

    // MARK: - Reconocimiento y ortografía

    /// Pasarle los términos del diccionario a whisper antes de transcribir, para
    /// que los oiga bien en vez de corregirlos después.
    var recognitionBiasEnabled: Bool {
        get { defaults.object(forKey: "recognitionBiasEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "recognitionBiasEnabled") }
    }

    /// Corrección ortográfica con el corrector del sistema.
    var spellFixEnabled: Bool {
        get { defaults.object(forKey: "spellFixEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "spellFixEnabled") }
    }

    // MARK: - Snippets por voz

    // MARK: - Atajos

    /// Modificadores del atajo, guardados como el rawValue de ModifierFlags.
    /// Sin valor guardado se usa el de fábrica de cada acción.
    func hotkeyModifiers(for action: HotkeyBinding.Action) -> NSEvent.ModifierFlags {
        let key = "hotkey.\(action.rawValue).modifiers"
        guard let raw = defaults.object(forKey: key) as? UInt else {
            return action.defaultModifiers
        }
        return NSEvent.ModifierFlags(rawValue: raw)
    }

    func setHotkeyModifiers(_ modifiers: NSEvent.ModifierFlags,
                            for action: HotkeyBinding.Action) {
        defaults.set(modifiers.rawValue, forKey: "hotkey.\(action.rawValue).modifiers")
    }

    func hotkeyMode(for action: HotkeyBinding.Action) -> HotkeyBinding.Mode {
        guard action.supportsModes,
              let raw = defaults.string(forKey: "hotkey.\(action.rawValue).mode"),
              let mode = HotkeyBinding.Mode(rawValue: raw) else { return .hold }
        return mode
    }

    func setHotkeyMode(_ mode: HotkeyBinding.Mode, for action: HotkeyBinding.Action) {
        defaults.set(mode.rawValue, forKey: "hotkey.\(action.rawValue).mode")
    }

    /// Los tres atajos tal como están configurados.
    var hotkeyBindings: [HotkeyBinding] {
        HotkeyBinding.Action.allCases.map {
            HotkeyBinding(action: $0,
                          modifiers: hotkeyModifiers(for: $0),
                          mode: hotkeyMode(for: $0))
        }
    }

    // MARK: - Píldora flotante

    /// Palabra en reposo de la píldora. Se persiste para que reiniciar la app no
    /// fuerce un cambio: la regla es que la palabra no se mueva a la vista.
    var idleWordIndex: Int {
        get { defaults.integer(forKey: "idleWordIndex") }
        set { defaults.set(newValue, forKey: "idleWordIndex") }
    }

    var idleWordChangedAt: Date? {
        get { defaults.object(forKey: "idleWordChangedAt") as? Date }
        set { defaults.set(newValue, forKey: "idleWordChangedAt") }
    }

    /// Si los snippets se insertan al pronunciar sus disparadores.
    /// Sin snippets registrados es inerte, así que el default es true.
    var snippetsEnabled: Bool {
        get { defaults.object(forKey: "snippetsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "snippetsEnabled") }
    }

    // MARK: - Validación

    var isWhisperCliValid: Bool {
        FileManager.default.isExecutableFile(atPath: whisperCliPath)
    }

    var isModelValid: Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    var isValid: Bool { isWhisperCliValid && isModelValid }

    var isLlmCliValid: Bool {
        FileManager.default.isExecutableFile(atPath: llmCliPath)
    }

    /// Un `.bin` de whisper existe y se deja elegir, pero llama-completion no lo
    /// puede cargar. Sin comprobar la extensión, la app se creía configurada y
    /// fallaba en cada dictado con «se pegó el texto sin corregir».
    var isLlmModelValid: Bool {
        Config.isGGUF(llmModelPath) && FileManager.default.fileExists(atPath: llmModelPath)
    }

    static func isGGUF(_ path: String) -> Bool {
        !path.isEmpty && path.lowercased().hasSuffix(".gguf")
    }

    // MARK: - Auto-detección

    /// Busca whisper-cli en rutas comunes de Homebrew (Apple Silicon e Intel)
    static func detectWhisperCli() -> String? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",   // Apple Silicon
            "/usr/local/bin/whisper-cli",       // Intel
            "/usr/bin/whisper-cli",
        ]
        if let found = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) { return found }

        // Último recurso: `which whisper-cli`
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["whisper-cli"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                          encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    /// Busca modelos en la carpeta estándar, en orden de preferencia
    static func detectModel() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.whisper-realtime/ggml-large-v3.bin",
            "\(home)/.whisper-realtime/ggml-large-v2.bin",
            "\(home)/.whisper-realtime/ggml-medium.bin",
            "\(home)/.whisper-realtime/ggml-small.bin",
            "\(home)/.whisper-realtime/ggml-base.bin",
            "\(home)/.whisper-realtime/ggml-tiny.bin",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Busca llama-completion en rutas comunes de Homebrew (single-shot, sin modo conversación)
    static func detectLlmCli() -> String? {
        let candidates = [
            "/opt/homebrew/bin/llama-completion",   // Apple Silicon
            "/usr/local/bin/llama-completion",       // Intel
            "/opt/homebrew/bin/llama-cli",           // fallback legacy
            "/usr/local/bin/llama-cli",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Busca modelos .gguf en la carpeta estándar
    static func detectLlmModel() -> String? {
        let dir = "\(NSHomeDirectory())/.whisper-realtime"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }
        return files
            .filter { $0.hasSuffix(".gguf") }
            .sorted()
            .first
            .map { "\(dir)/\($0)" }
    }

    /// Busca whisper-stream en rutas comunes de Homebrew
    static func detectWhisperStream() -> String? {
        let candidates = [
            "/opt/homebrew/bin/whisper-stream",   // Apple Silicon
            "/usr/local/bin/whisper-stream",       // Intel
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
