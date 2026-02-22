import Foundation

/// Traduce audio a texto en el idioma destino configurado.
/// Si target=en → usa whisper-cli -tr (sin LLM). Si target≠en → whisper + LLM traduce.
class TranslationProcessor {

    private let config = Config.shared
    private let llmProcessor = LLMProcessor()
    private let timeout: TimeInterval = 60

    enum TranslationError: LocalizedError {
        case invalidConfig
        case timeout
        case emptyOutput
        case llmRequired

        var errorDescription: String? {
            switch self {
            case .invalidConfig: return "Config inválida para traducción."
            case .timeout:       return "Traducción timeout (>60s)."
            case .emptyOutput:   return "Traducción no devolvió texto."
            case .llmRequired:   return "Traducción a \(Config.shared.translationTargetLanguage) requiere LLM activado."
            }
        }
    }

    /// Traduce el audio de la URL dada al idioma configurado.
    func translate(audioURL: URL) -> Result<String, Error> {
        let target = config.translationTargetLanguage

        if target == "en" {
            // whisper-cli tiene -tr built-in para traducir a inglés
            return transcribeWithTranslation(url: audioURL)
        } else {
            // Paso 1: Transcribir normalmente
            let transcriber = Transcriber()
            switch transcriber.transcribe(url: audioURL) {
            case .success(let text) where !text.isEmpty:
                // Paso 2: Traducir via LLM
                return translateViaLLM(text: text, targetLanguage: target)
            case .success:
                return .failure(TranslationError.emptyOutput)
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    /// Invoca whisper-cli con -tr para traducción directa a inglés.
    private func transcribeWithTranslation(url: URL) -> Result<String, Error> {
        guard config.isValid else {
            return .failure(TranslationError.invalidConfig)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.whisperCliPath)
        proc.arguments = [
            "-m", config.modelPath,
            "-l", config.language,
            "--no-timestamps",
            "-tr",
            "-f", url.path,
        ]

        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = Pipe()

        do { try proc.run() } catch { return .failure(error) }

        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { proc.waitUntilExit(); sem.signal() }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return .failure(TranslationError.timeout)
        }

        let raw = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        let text = raw
            .components(separatedBy: .newlines)
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
            .joined(separator: " ")

        return text.isEmpty ? .failure(TranslationError.emptyOutput) : .success(text)
    }

    /// Usa LLM para traducir texto al idioma destino.
    private func translateViaLLM(text: String, targetLanguage: String) -> Result<String, Error> {
        guard config.llmEnabled, config.isLlmCliValid, config.isLlmModelValid else {
            return .failure(TranslationError.llmRequired)
        }

        let langName = Config.languageName(for: targetLanguage)
        let prompt = "Traduce el siguiente texto a \(langName). Devuelve SOLO el texto traducido, nada más."
        return llmProcessor.process(text: text, systemPrompt: prompt)
    }
}
