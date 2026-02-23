import Cocoa
import Foundation

/// Ejecuta acciones de voz usando APIs del sistema macOS.
class VoiceActionExecutor {

    /// Ejecuta un intent y retorna mensaje descriptivo del resultado.
    func execute(_ intent: VoiceActionIntent) -> String {
        switch intent {
        case .webSearch(let query):
            return openWebSearch(query: query)
        case .createReminder(let title):
            return createReminder(title: title)
        case .openApp(let appName):
            return openApplication(name: appName)
        case .translateLast(let targetLanguage):
            return retranslate(targetLanguage: targetLanguage)
        case .none:
            return ""
        }
    }

    // MARK: - Búsqueda web

    private func openWebSearch(query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
            return "🔍 Buscando: \(query)"
        }
        return "❌ Error al buscar"
    }

    // MARK: - Recordatorios via AppleScript

    private func createReminder(title: String) -> String {
        let escaped = title.replacingOccurrences(of: "\"", with: "\\\"")
        // Usar osascript via Process (funciona desde cualquier thread y respeta
        // NSAppleEventsUsageDescription para solicitar permisos de Automation)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = [
            "-e",
            "tell application \"Reminders\" to make new reminder with properties {name: \"\(escaped)\"}"
        ]
        let errPipe = Pipe()
        proc.standardOutput = Pipe()
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return "❌ Error ejecutando osascript: \(error.localizedDescription)"
        }
        if proc.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "desconocido"
            return "❌ Error creando recordatorio: \(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return "✅ Recordatorio: \(title)"
    }

    // MARK: - Abrir aplicación

    private func openApplication(name: String) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", name]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
            ? "✅ Abriendo \(name)"
            : "❌ App no encontrada: \(name)"
    }

    // MARK: - Retraducir último texto

    private func retranslate(targetLanguage: String) -> String {
        guard let lastEntry = TranscriptionHistory.shared.allEntries.first else {
            return "❌ No hay transcripción anterior"
        }

        let langName = Config.languageName(for: targetLanguage)
        let prompt = "Traduce el siguiente texto a \(langName). Devuelve SOLO el texto traducido."
        let llm = LLMProcessor()
        switch llm.process(text: lastEntry.text, systemPrompt: prompt) {
        case .success(let translated):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(translated, forType: .string)
            return "🌐 Traducido a \(langName) y copiado"
        case .failure(let error):
            return "❌ Error: \(error.localizedDescription)"
        }
    }
}
