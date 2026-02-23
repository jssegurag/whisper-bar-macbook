import Foundation

/// Gestiona un proceso whisper-stream para transcripción en tiempo real.
/// Procesa stdout con semántica de líneas: \r = reemplazo progresivo, \n = línea finalizada.
class StreamingTranscriber {

    private let config = Config.shared
    private var process: Process?
    private var outputPipe: Pipe?
    private(set) var isRunning = false

    /// Callback en main thread con texto finalizado (confirmado — agregar al transcript).
    var onFinalizedText: ((String) -> Void)?
    /// Callback en main thread con texto parcial actual (reemplaza el parcial anterior).
    var onPartialUpdate: ((String) -> Void)?

    /// Buffer para datos crudos incompletos entre lecturas de stdout.
    private var rawBuffer = ""

    // MARK: - Validación

    var isValid: Bool {
        FileManager.default.isExecutableFile(atPath: config.whisperStreamPath)
            && config.isModelValid
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning, isValid else { return }
        rawBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.whisperStreamPath)
        proc.arguments = [
            "-m", config.modelPath,
            "-l", config.language,
            "--step", String(config.streamStepMs),
            "--length", String(config.streamLengthMs),
            "--keep", String(config.streamKeepMs),
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        proc.standardInput  = FileHandle.nullDevice

        // Leer stdout asincrónicamente
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                self?.processChunk(text)
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.outputPipe = pipe
            self.isRunning = true
        } catch {
            // Fallo silencioso — el panel mostrará que no está activo
        }
    }

    func stop() {
        guard isRunning else { return }
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
        rawBuffer = ""
    }

    // MARK: - Procesamiento de chunks

    /// Procesa un chunk crudo de whisper-stream.
    ///
    /// whisper-stream usa `\033[2K\r` para reescribir la línea actual (transcripción progresiva)
    /// y `\n` para finalizar una línea y pasar a la siguiente.
    ///
    /// Protocolo:
    /// - Texto entre `\r` dentro de una misma línea = reemplazo progresivo (solo el último importa)
    /// - Texto seguido de `\n` = línea finalizada (confirmada, se agrega al transcript)
    /// - Texto después del último `\n` = línea parcial actual (se muestra pero puede cambiar)
    private func processChunk(_ chunk: String) {
        rawBuffer += chunk

        // Separar por \n para encontrar líneas finalizadas
        let parts = rawBuffer.components(separatedBy: "\n")

        // Todas las partes excepto la última fueron seguidas por \n — están finalizadas
        for i in 0..<(parts.count - 1) {
            let finalVersion = extractFinalVersion(of: parts[i])
            let cleaned = cleanLine(finalVersion)
            if !cleaned.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onFinalizedText?(cleaned)
                }
            }
        }

        // La última parte es la línea actual incompleta
        rawBuffer = parts.last ?? ""

        // Emitir actualización parcial para display en tiempo real
        let partialFinal = extractFinalVersion(of: rawBuffer)
        let cleanedPartial = cleanLine(partialFinal)
        DispatchQueue.main.async { [weak self] in
            self?.onPartialUpdate?(cleanedPartial)
        }
    }

    /// De una línea que puede contener múltiples `\r` o `\033[2K` (reescrituras progresivas),
    /// extrae la versión final: el texto después del último \r (que es la versión más reciente).
    private func extractFinalVersion(of line: String) -> String {
        // Split por \r — whisper-stream envía \033[2K\r antes de cada reescritura
        let segments = line.components(separatedBy: "\r")
        // Tomar el último segmento no vacío (después de quitar ANSI)
        for segment in segments.reversed() {
            let stripped = stripAnsiCodes(segment)
            if !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return stripped
            }
        }
        return ""
    }

    // MARK: - Limpieza de texto

    /// Regex para secuencias de escape ANSI: \033[...X (ej: \033[2K, \033[0m, \033[H)
    private static let ansiRegex = try! NSRegularExpression(
        pattern: "\\x1b\\[[0-9;]*[A-Za-z]", options: [])

    /// Frases alucinadas comunes de whisper en silencio (dataset YouTube).
    private static let hallucinationPatterns: [String] = [
        "gracias por ver",
        "gracias por ver el video",
        "gracias por ver el vídeo",
        "thank you for watching",
        "thanks for watching",
        "subtítulos realizados por",
        "subtítulos por",
        "suscríbete",
        "like and subscribe",
        "no olvides suscribirte",
        "hasta la próxima",
        "nos vemos en el próximo",
        "gracias.",
        "gracias",
    ]

    /// Quita códigos de escape ANSI de un string.
    private func stripAnsiCodes(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return StreamingTranscriber.ansiRegex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: "")
    }

    /// Limpia una línea individual: quita caracteres de control, timestamps, alucinaciones.
    private func cleanLine(_ text: String) -> String {
        // Strip caracteres de control residuales (excepto newline)
        var cleaned = text.unicodeScalars.filter {
            $0 == "\n" || !CharacterSet.controlCharacters.contains($0)
        }.map { String($0) }.joined()

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "" }

        // Filtrar timestamps: [00:05.000 --> 00:08.000] etc
        if cleaned.hasPrefix("[") { return "" }

        // Filtrar alucinaciones conocidas
        let lower = cleaned.lowercased()
        for pattern in StreamingTranscriber.hallucinationPatterns {
            if lower == pattern || lower.hasPrefix(pattern) {
                return ""
            }
        }

        return cleaned
    }
}
