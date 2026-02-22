import Foundation

/// Procesa texto a través de llama-cli para corrección ortográfica y puntuación.
class LLMProcessor {

    private let config  = Config.shared
    private let timeout: TimeInterval = 30

    enum LLMError: LocalizedError {
        case disabled
        case invalidConfig
        case timeout
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .disabled:    return "LLM deshabilitado."
            case .invalidConfig: return "Config LLM inválida — verifica llama-cli y modelo."
            case .timeout:     return "LLM timeout (>30s)."
            case .emptyOutput: return "LLM no devolvió texto."
            }
        }
    }

    /// Corrige el texto con LLM. Retorna el texto original si LLM está deshabilitado.
    func process(text: String) -> Result<String, Error> {
        guard config.llmEnabled else { return .success(text) }
        guard config.isLlmCliValid, config.isLlmModelValid else {
            return .failure(LLMError.invalidConfig)
        }

        let fullPrompt = "\(config.llmPrompt)\n\nTexto: \(text)"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.llmCliPath)
        proc.arguments = [
            "-m", config.llmModelPath,
            "-p", fullPrompt,
            "-n", "512",
            "--no-display-prompt",
            "-ngl", "99",
        ]

        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = Pipe()

        do { try proc.run() } catch { return .failure(error) }

        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { proc.waitUntilExit(); sem.signal() }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return .failure(LLMError.timeout)
        }

        let raw = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? .failure(LLMError.emptyOutput) : .success(cleaned)
    }
}
