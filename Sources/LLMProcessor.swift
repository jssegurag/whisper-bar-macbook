import Foundation

/// Procesa texto a través de llama-completion para corrección ortográfica y puntuación.
class LLMProcessor {

    private let config  = Config.shared
    private let timeout: TimeInterval = 30

    enum LLMError: LocalizedError {
        case disabled
        case invalidConfig
        case timeout
        case emptyOutput
        case processError(String)

        var errorDescription: String? {
            switch self {
            case .disabled:    return "LLM deshabilitado."
            case .invalidConfig: return "Config LLM inválida — verifica llama-completion y modelo."
            case .timeout:     return "LLM timeout (>30s)."
            case .emptyOutput: return "LLM no devolvió texto."
            case .processError(let msg): return "LLM error: \(msg)"
            }
        }
    }

    /// Corrige el texto con LLM. Retorna el texto original si LLM está deshabilitado.
    func process(text: String) -> Result<String, Error> {
        guard config.llmEnabled else { return .success(text) }
        return process(text: text, systemPrompt: config.llmPrompt)
    }

    /// Procesa texto con un prompt de sistema personalizado (acciones, traducción, etc.)
    func process(text: String, systemPrompt: String) -> Result<String, Error> {
        guard config.isLlmCliValid, config.isLlmModelValid else {
            return .failure(LLMError.invalidConfig)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.llmCliPath)
        proc.arguments = [
            "-m", config.llmModelPath,
            "-sys", systemPrompt,
            "-p", text,
            "-n", "512",
            "-ngl", "99",
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = errPipe
        proc.standardInput  = FileHandle.nullDevice   // cerrar stdin → sale tras primer turno

        do { try proc.run() } catch { return .failure(error) }

        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { proc.waitUntilExit(); sem.signal() }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return .failure(LLMError.timeout)
        }

        // Verificar exit code
        if proc.terminationStatus != 0 {
            let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? "exit code \(proc.terminationStatus)"
            return .failure(LLMError.processError(errMsg.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        let raw = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""

        // Extraer solo la respuesta del assistant del formato chat:
        // "user\n{prompt}\nassistant\n{response}\n> EOF by user"
        let cleaned = extractAssistantResponse(from: raw)

        return cleaned.isEmpty ? .failure(LLMError.emptyOutput) : .success(cleaned)
    }

    /// Extrae la respuesta del assistant del output con formato chat de llama-completion.
    private func extractAssistantResponse(from raw: String) -> String {
        // Buscar "assistant\n" como marcador de inicio de respuesta
        if let range = raw.range(of: "assistant\n") {
            let afterAssistant = String(raw[range.upperBound...])
            // Limpiar: quitar líneas de control y "EOF by user"
            return afterAssistant
                .components(separatedBy: .newlines)
                .filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return !trimmed.isEmpty
                        && !trimmed.hasPrefix(">")
                        && !trimmed.hasPrefix("▄")
                        && !trimmed.hasPrefix("█")
                        && !trimmed.hasPrefix("▀")
                        && !trimmed.hasPrefix("[")
                        && !trimmed.hasPrefix("|-")
                        && !trimmed.contains("EOF by user")
                }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: si no hay marcador "assistant", filtrar todo el output
        return raw
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty
                    && trimmed != "user"
                    && trimmed != "assistant"
                    && !trimmed.hasPrefix(">")
                    && !trimmed.hasPrefix("▄")
                    && !trimmed.hasPrefix("█")
                    && !trimmed.hasPrefix("▀")
                    && !trimmed.hasPrefix("[")
                    && !trimmed.hasPrefix("|-")
                    && !trimmed.contains("EOF by user")
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
