import Foundation

/// Traduce lo que dictas al inglés, con whisper.
///
/// **Solo al inglés, y no es una limitación de Gluffi:** whisper trae `-tr`, que
/// traduce hacia inglés y nada más. No existe la dirección contraria.
///
/// Hubo una segunda vía que pasaba la transcripción por un modelo de lenguaje
/// para llegar a otros idiomas. Se quitó: obligaba a descargar un gigabyte para
/// una traducción de calidad incierta, cuando quien necesita traducir a otro
/// idioma tiene herramientas mejores a un atajo de distancia.
class TranslationProcessor {

    private let timeout: TimeInterval = 60

    enum TranslationError: LocalizedError {
        case invalidConfig
        case timeout
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .invalidConfig: return "Falta el motor o el modelo de voz."
            case .timeout:       return "La traducción tardó demasiado (>60s)."
            case .emptyOutput:   return "No se entendió nada del audio."
            }
        }
    }

    /// Traduce el audio al inglés.
    func translate(audioURL: URL,
                   session: DictationSession = .global()) -> Result<String, Error> {
        transcribeWithTranslation(url: audioURL, session: session)
    }

    /// Invoca whisper-cli con -tr para traducción directa a inglés.
    private func transcribeWithTranslation(url: URL,
                                           session: DictationSession) -> Result<String, Error> {
        guard session.isValid else {
            return .failure(TranslationError.invalidConfig)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: session.whisperCliPath)
        proc.arguments = [
            "-m", session.modelPath,
            "-l", session.language,
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

}
