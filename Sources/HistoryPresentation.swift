import Foundation

/// Textos y formatos del Historial. Funciones puras, para poder probarlas.
enum HistoryPresentation {

    /// Mensaje del estado vacío. Son tres situaciones distintas y antes se
    /// resolvían con dos frases genéricas —«Sin transcripciones aún» y «Sin
    /// resultados»— que no decían qué hacer.
    static func emptyMessage(total: Int, query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "Nada coincide con «\(trimmed)»."
        }
        if total == 0 {
            return "Aún no has dictado nada. Lo que dictes aparecerá aquí."
        }
        return "Historial vacío."
    }

    /// Contador junto al buscador. Solo aparece buscando: sin búsqueda el total
    /// ya está en el pie.
    static func resultsLabel(count: Int) -> String {
        count == 1 ? "1 resultado" : "\(count) resultados"
    }

    /// Nombre del perfil de una entrada, o `nil` si no hay que enseñar nada.
    ///
    /// Se resuelve al pintar, contra el store, en vez de leerse de la entrada:
    /// así renombrar un perfil se refleja en el historial, y un perfil borrado
    /// deja de nombrarse en lugar de mentir con un nombre que ya no existe.
    /// Las preferencias globales no son un perfil, así que no se etiquetan.
    static func profileLabel(_ id: UUID?, in store: ProfileStore) -> String? {
        guard let id else { return nil }
        return store.profile(with: id)?.name
    }

    static func time(_ date: Date, now: Date = Date(), locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        if Calendar.current.isDate(date, inSameDayAs: now) {
            // Dentro del mismo día la fecha es ruido: la hora basta.
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        seconds < 60
            ? String(format: "%.1f s", seconds)
            : String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

/// Metadatos de la ventana de transcripción en vivo.
enum LiveMeta {

    static func words(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Reloj sin ceros de más: 2:18 y 1:02:03, no 00:02:18.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// Lo que va tras el estado en la cabecera. Sin texto todavía no se muestran
    /// las palabras: «0 palabras» no informa de nada.
    static func summary(words: Int, seconds: TimeInterval) -> String {
        var parts: [String] = []
        if words > 0 { parts.append(words == 1 ? "1 palabra" : "\(words) palabras") }
        if seconds >= 1 { parts.append(clock(seconds)) }
        return parts.isEmpty ? "" : "· " + parts.joined(separator: " · ")
    }
}
