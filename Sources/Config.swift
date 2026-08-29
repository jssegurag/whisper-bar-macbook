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





    // MARK: - Traducción por voz

    /// Si la traducción por voz está habilitada
    var translationEnabled: Bool {
        get { defaults.bool(forKey: "translationEnabled") }
        set { defaults.set(newValue, forKey: "translationEnabled") }
    }


    // MARK: - Acciones por voz


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

    // MARK: - Limpieza automática del dictado

    /// Cuánto se limpia lo dictado antes de tocar el diccionario.
    /// El valor vive en `cleanupLevel` para que se pueda cambiar con
    /// `defaults write com.user.WhisperBar cleanupLevel completo`.
    ///
    /// Por defecto `conservador`: quita muletillas entre pausas y repeticiones
    /// seguidas, que es lo que el usuario borraría a mano de todos modos. Las
    /// reglas que reescriben estructura —autocorrecciones y listas— exigen
    /// pedirlas: se equivocan de forma más cara.
    var cleanupLevel: CleanupLevel {
        get {
            guard let raw = defaults.string(forKey: "cleanupLevel"),
                  let level = CleanupLevel(rawValue: raw) else { return .conservador }
            return level
        }
        set { defaults.set(newValue.rawValue, forKey: "cleanupLevel") }
    }

    // MARK: - Reconocimiento y ortografía

    /// Pasarle los términos del diccionario a whisper antes de transcribir, para
    /// que los oiga bien en vez de corregirlos después.
    var recognitionBiasEnabled: Bool {
        get { defaults.object(forKey: "recognitionBiasEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "recognitionBiasEnabled") }
    }

    /// Repaso con el modelo de lenguaje que trae macOS. Apagado por defecto:
    /// añade un par de segundos por dictado y el corrector ortográfico ya cubre
    /// lo habitual.
    var systemPolishEnabled: Bool {
        get { defaults.object(forKey: "systemPolishEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "systemPolishEnabled") }
    }

    /// Corrección ortográfica con el corrector del sistema.
    var spellFixEnabled: Bool {
        get { defaults.object(forKey: "spellFixEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "spellFixEnabled") }
    }

    // MARK: - Modelo de lenguaje local

    /// Ruta del modelo GGUF. Vacía = autodetectar, para que cambiar de modelo sea
    /// dejar el archivo en la carpeta y no editar ajustes.
    var llmModelPath: String {
        get {
            if let saved = defaults.string(forKey: "llmModelPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectLlmModel() ?? ""
        }
        set { defaults.set(newValue, forKey: "llmModelPath") }
    }

    /// Ruta de llama-server. Se usa el servidor y no llama-cli a propósito:
    /// medido en este proyecto, una llamada suelta tarda ~25 s porque recarga el
    /// modelo entero, contra ~1,5 s con el modelo ya residente.
    var llamaServerPath: String {
        get {
            if let saved = defaults.string(forKey: "llamaServerPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectLlamaServer() ?? ""
        }
        set { defaults.set(newValue, forKey: "llamaServerPath") }
    }

    /// Ventana de contexto. Más contexto es más RAM, no más calidad.
    var llmContextSize: Int {
        get {
            let v = defaults.integer(forKey: "llmContextSize")
            return v > 0 ? v : 4096
        }
        set { defaults.set(max(512, min(32768, newValue)), forKey: "llmContextSize") }
    }

    /// Minutos de inactividad antes de apagar el servidor. No es un adorno: el
    /// modelo residente ocupa ~3 GB de RAM, que en un Air de 8 GB se nota.
    var llmIdleMinutes: Int {
        get {
            let v = defaults.integer(forKey: "llmIdleMinutes")
            return v > 0 ? v : 5
        }
        set { defaults.set(max(1, min(120, newValue)), forKey: "llmIdleMinutes") }
    }

    var isLlmModelValid: Bool {
        !llmModelPath.isEmpty && FileManager.default.fileExists(atPath: llmModelPath)
    }

    var isLlamaServerValid: Bool {
        !llamaServerPath.isEmpty
            && FileManager.default.isExecutableFile(atPath: llamaServerPath)
    }

    var isLlmValid: Bool { isLlmModelValid && isLlamaServerValid }

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



    /// Busca llama-server en rutas comunes de Homebrew
    static func detectLlamaServer() -> String? {
        let candidates = [
            "/opt/homebrew/bin/llama-server",   // Apple Silicon
            "/usr/local/bin/llama-server",       // Intel
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Busca un GGUF en la carpeta de modelos. Se listan los nombres conocidos
    /// primero y luego se acepta cualquier .gguf: el usuario puede cambiar de
    /// modelo, y una lista fija dejaría de encontrarlo en cuanto lo hiciera.
    static func detectLlmModel() -> String? {
        let dir = "\(NSHomeDirectory())/.whisper-realtime"
        let preferidos = [
            "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
            "Qwen3-1.7B-Q4_K_M.gguf",
        ]
        for nombre in preferidos {
            let ruta = "\(dir)/\(nombre)"
            if FileManager.default.fileExists(atPath: ruta) { return ruta }
        }
        let sueltos = (try? FileManager.default.contentsOfDirectory(atPath: dir))?
            .filter { $0.hasSuffix(".gguf") }
            .sorted()
        return sueltos?.first.map { "\(dir)/\($0)" }
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
