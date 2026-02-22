import Foundation

/// Representa una acción de voz detectada.
enum VoiceActionIntent {
    case webSearch(query: String)
    case createReminder(title: String)
    case openApp(appName: String)
    case translateLast(targetLanguage: String)
    case none(originalText: String)
}

/// Detecta intents de comandos de voz usando LLM con output estructurado.
class VoiceActionDetector {

    private let config = Config.shared
    private let llmProcessor = LLMProcessor()

    private let detectionPrompt = """
    Analyze the following voice transcription and determine if it contains a command.
    Respond with EXACTLY one line in this format:

    ACTION:web_search|QUERY:<search terms>
    ACTION:create_reminder|TITLE:<reminder text>
    ACTION:open_app|APP:<app name>
    ACTION:translate_last|LANG:<language code>
    ACTION:none|TEXT:<original text>

    Rules:
    - "Busca en Google..." or "Busca..." or "Search for..." → web_search
    - "Crea recordatorio..." or "Recuérdame..." or "Remind me..." → create_reminder
    - "Abre..." or "Open..." → open_app
    - "Traduce al... lo último" → translate_last
    - If no command is detected, respond with ACTION:none|TEXT: followed by the original text
    - Respond with ONLY the ACTION line, nothing else.
    """

    /// Detecta intent del texto transcrito. Retorna .none si no hay acción.
    func detect(text: String) -> VoiceActionIntent {
        guard config.voiceActionsEnabled else {
            return .none(originalText: text)
        }
        guard config.isLlmCliValid, config.isLlmModelValid else {
            return .none(originalText: text)
        }

        switch llmProcessor.process(text: text, systemPrompt: detectionPrompt) {
        case .success(let response):
            return parseResponse(response, originalText: text)
        case .failure:
            return .none(originalText: text)
        }
    }

    /// Parsea la respuesta estructurada del LLM.
    private func parseResponse(_ response: String, originalText: String) -> VoiceActionIntent {
        let lines = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        let trimmed = (lines.first ?? "").trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("ACTION:web_search|QUERY:") {
            let query = String(trimmed.dropFirst("ACTION:web_search|QUERY:".count))
                .trimmingCharacters(in: .whitespaces)
            return query.isEmpty ? .none(originalText: originalText) : .webSearch(query: query)
        }
        if trimmed.hasPrefix("ACTION:create_reminder|TITLE:") {
            let title = String(trimmed.dropFirst("ACTION:create_reminder|TITLE:".count))
                .trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? .none(originalText: originalText) : .createReminder(title: title)
        }
        if trimmed.hasPrefix("ACTION:open_app|APP:") {
            let app = String(trimmed.dropFirst("ACTION:open_app|APP:".count))
                .trimmingCharacters(in: .whitespaces)
            return app.isEmpty ? .none(originalText: originalText) : .openApp(appName: app)
        }
        if trimmed.hasPrefix("ACTION:translate_last|LANG:") {
            let lang = String(trimmed.dropFirst("ACTION:translate_last|LANG:".count))
                .trimmingCharacters(in: .whitespaces)
            return lang.isEmpty ? .none(originalText: originalText) : .translateLast(targetLanguage: lang)
        }

        return .none(originalText: originalText)
    }
}
