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
    You classify voice transcriptions as commands or normal text.
    IMPORTANT: Most transcriptions are normal dictated text, NOT commands.
    Only classify as a command if the text STARTS with a clear imperative verb directed at the system.

    Respond with EXACTLY one line. Choose one:
    ACTION:none|TEXT:original text here
    ACTION:web_search|QUERY:search terms here
    ACTION:create_reminder|TITLE:reminder text here
    ACTION:open_app|APP:app name here
    ACTION:translate_last|LANG:language code here

    STRICT command triggers (must START the text):
    - web_search: "Busca en Google...", "Busca en internet...", "Search for..."
    - create_reminder: "Crea recordatorio...", "Crea un recordatorio...", "Recuérdame que..."
    - open_app: "Abre...", "Open..."
    - translate_last: "Traduce al... lo último", "Traduce esto al..."

    ALWAYS respond ACTION:none for these (NOT commands):
    - Normal sentences, opinions, descriptions, narrations
    - Text that mentions searching/reminding but is not a direct command
    - "necesito recordar algo" → none (not imperative)
    - "estoy buscando trabajo" → none (not a search command)
    - "recuerda que ayer fuimos" → none (narration, not a reminder command)
    - "hay que abrir la puerta" → none (not an app command)
    - "me gustaría buscar información" → none (not imperative)

    When in doubt, ALWAYS choose ACTION:none. Only ONE line, nothing else.
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
    /// Busca el patrón ACTION: en cualquier parte del string para ser robusto
    /// ante el join de líneas que hace LLMProcessor.extractAssistantResponse.
    func parseResponse(_ response: String, originalText: String) -> VoiceActionIntent {
        // Buscar "ACTION:" en cualquier parte del response (protege contra join de líneas)
        guard let actionRange = response.range(of: "ACTION:") else {
            return .none(originalText: originalText)
        }

        let fromAction = String(response[actionRange.lowerBound...])
        // Tomar solo hasta el primer newline (por si hay basura después)
        let actionLine = fromAction.components(separatedBy: .newlines).first ?? fromAction
        let trimmed = actionLine.trimmingCharacters(in: .whitespaces)

        // ACTION:none → siempre retornar texto original
        if trimmed.hasPrefix("ACTION:none") {
            return .none(originalText: originalText)
        }

        if trimmed.hasPrefix("ACTION:web_search|QUERY:") {
            let query = extractParam(from: trimmed, prefix: "ACTION:web_search|QUERY:")
            return query.isEmpty ? .none(originalText: originalText) : .webSearch(query: query)
        }
        if trimmed.hasPrefix("ACTION:create_reminder|TITLE:") {
            let title = extractParam(from: trimmed, prefix: "ACTION:create_reminder|TITLE:")
            return title.isEmpty ? .none(originalText: originalText) : .createReminder(title: title)
        }
        if trimmed.hasPrefix("ACTION:open_app|APP:") {
            let app = extractParam(from: trimmed, prefix: "ACTION:open_app|APP:")
            return app.isEmpty ? .none(originalText: originalText) : .openApp(appName: app)
        }
        if trimmed.hasPrefix("ACTION:translate_last|LANG:") {
            let lang = extractParam(from: trimmed, prefix: "ACTION:translate_last|LANG:")
            return lang.isEmpty ? .none(originalText: originalText) : .translateLast(targetLanguage: lang)
        }

        return .none(originalText: originalText)
    }

    /// Extrae el parámetro después del prefix, limpiando whitespace.
    func extractParam(from line: String, prefix: String) -> String {
        String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}
