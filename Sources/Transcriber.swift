import Foundation

/// Invoca whisper-cli para transcribir un archivo de audio.
class Transcriber {

    private let config = Config.shared
    private let timeout: TimeInterval = 60

    enum TranscriberError: LocalizedError {
        case invalidConfig(whisperCli: String, model: String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidConfig(let cli, let model):
                return "Configuración inválida.\nwhisper-cli: \(cli)\nModelo: \(model)"
            case .timeout:
                return "Tiempo de espera agotado (>\(Int(60))s). Prueba un modelo más pequeño."
            }
        }
    }

    // MARK: - Transcripción

    /// Transcribe el archivo en `url` y devuelve el texto limpio.
    func transcribe(url: URL) -> Result<String, Error> {
        guard config.isValid else {
            return .failure(TranscriberError.invalidConfig(
                whisperCli: config.whisperCliPath,
                model:       config.modelPath
            ))
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.whisperCliPath)
        proc.arguments = [
            "-m", config.modelPath,
            "-l", config.language,
            "--no-timestamps",
            "-f", url.path,
        ]

        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = Pipe()

        do { try proc.run() } catch { return .failure(error) }

        // Timeout: evita que la app se cuelgue si whisper-cli falla silenciosamente
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { proc.waitUntilExit(); sem.signal() }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return .failure(TranscriberError.timeout)
        }

        let raw = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        let text = raw
            .components(separatedBy: .newlines)
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }   // elimina líneas de timestamp
            .joined(separator: " ")

        return .success(text)
    }
}
