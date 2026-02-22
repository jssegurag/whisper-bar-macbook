import Foundation

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

    /// Ruta al binario llama-cli
    var llmCliPath: String {
        get {
            if let saved = defaults.string(forKey: "llmCliPath"), !saved.isEmpty {
                return saved
            }
            return Config.detectLlmCli() ?? "/opt/homebrew/bin/llama-cli"
        }
        set { defaults.set(newValue, forKey: "llmCliPath") }
    }

    /// Ruta al modelo LLM (.gguf)
    var llmModelPath: String {
        get {
            if let saved = defaults.string(forKey: "llmModelPath"), !saved.isEmpty {
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

    var isLlmModelValid: Bool {
        !llmModelPath.isEmpty && FileManager.default.fileExists(atPath: llmModelPath)
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

    /// Busca llama-cli en rutas comunes de Homebrew
    static func detectLlmCli() -> String? {
        let candidates = [
            "/opt/homebrew/bin/llama-cli",
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
}
