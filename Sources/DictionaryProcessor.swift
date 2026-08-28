import Foundation

/// Motor de corrección del diccionario personalizado. Funciones puras: recibe
/// texto y entradas, devuelve texto. Sin estado, sin UI, sin subprocesos.
///
/// whisper parte los nombres en varias palabras ("DocFly" → "doc fly"), así que
/// la búsqueda recorre ventanas de 1 a N palabras y no token por token.
struct DictionaryProcessor {

    /// Índice de búsqueda: forma normalizada → forma canónica a escribir.
    struct Index {
        let byPhrase: [String: String]
        let maxWords: Int

        var isEmpty: Bool { byPhrase.isEmpty }
    }

    /// Caracteres que se ignoran en los bordes de una coincidencia pero se
    /// conservan en la salida: "doc fly." → "DocFly."
    private static let edgePunctuation = CharacterSet.punctuationCharacters
        .union(.symbols)
        .union(CharacterSet(charactersIn: "¿¡«»\"'"))

    // MARK: - Normalización

    /// Para comparar: minúsculas, sin acentos, espacios internos colapsados.
    /// Nunca se usa para escribir — la salida siempre es la forma canónica.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es"))
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Índice

    static func buildIndex(from entries: [DictionaryEntry]) -> Index {
        var byPhrase: [String: String] = [:]
        var maxWords = 0
        for entry in entries where entry.isActive {
            let canonical = entry.canonical.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else { continue }
            for form in entry.allForms {
                let key = normalize(form)
                guard !key.isEmpty else { continue }
                // Colisión: gana la entrada registrada primero. La de más
                // palabras gana por otra vía — apply() prueba las ventanas
                // largas antes que las cortas.
                if byPhrase[key] == nil {
                    byPhrase[key] = canonical
                    maxWords = max(maxWords, key.components(separatedBy: " ").count)
                }
            }
        }
        return Index(byPhrase: byPhrase, maxWords: maxWords)
    }

    // MARK: - Aplicación

    static func apply(to text: String, entries: [DictionaryEntry]) -> String {
        apply(to: text, index: buildIndex(from: entries))
    }

    /// Reescribe `text` sustituyendo cada coincidencia por su forma canónica.
    /// Preserva los espacios originales y la puntuación pegada a los bordes.
    static func apply(to text: String, index: Index) -> String {
        guard !index.isEmpty, !text.isEmpty else { return text }

        let (tokens, gaps, leading) = tokenize(text)
        guard !tokens.isEmpty else { return text }

        var result = leading
        var i = 0
        while i < tokens.count {
            var consumed = 1
            var replacement: String?

            // Coincidencia más larga primero: "Banco de Bogotá" gana sobre "Banco".
            let maxN = min(index.maxWords, tokens.count - i)
            if maxN >= 1 {
                for n in stride(from: maxN, through: 1, by: -1) {
                    guard let candidate = candidateKey(tokens: tokens, start: i, count: n) else { continue }
                    if let canonical = index.byPhrase[candidate.key] {
                        replacement = candidate.prefix + canonical + candidate.suffix
                        consumed = n
                        break
                    }
                }
            }

            result += replacement ?? tokens[i]
            result += gaps[i + consumed - 1]
            i += consumed
        }
        return result
    }

    // MARK: - Interno

    /// Parte el texto en tokens (secuencias sin espacios) y guarda los espacios
    /// tal cual para poder reconstruir el texto sin alterar saltos de línea.
    /// `gaps[j]` es lo que va después del token `j`.
    private static func tokenize(_ text: String) -> (tokens: [String], gaps: [String], leading: String) {
        var tokens: [String] = []
        var gaps: [String] = []
        var leading = ""
        var current = ""
        var currentGap = ""

        for char in text {
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                currentGap.append(char)
            } else {
                if !currentGap.isEmpty {
                    if tokens.isEmpty { leading = currentGap } else { gaps.append(currentGap) }
                    currentGap = ""
                }
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        // Cola final: el hueco que sigue al último token (puede ser vacío).
        if tokens.count > gaps.count { gaps.append(currentGap) }
        return (tokens, gaps, leading)
    }

    /// Construye la clave de búsqueda para la ventana `tokens[start..<start+count]`.
    /// La puntuación solo se recorta en los bordes externos: si un token interno
    /// trae puntuación ("doc, fly"), la ventana no coincide.
    private static func candidateKey(tokens: [String], start: Int, count: Int)
        -> (key: String, prefix: String, suffix: String)? {

        var parts: [String] = []
        var prefix = ""
        var suffix = ""

        for offset in 0..<count {
            var piece = tokens[start + offset]
            if offset == 0 {
                let split = trimLeadingPunctuation(piece)
                prefix = split.trimmed
                piece  = split.rest
            }
            if offset == count - 1 {
                let split = trimTrailingPunctuation(piece)
                suffix = split.trimmed
                piece  = split.rest
            }
            guard !piece.isEmpty else { return nil }
            parts.append(piece)
        }

        return (normalize(parts.joined(separator: " ")), prefix, suffix)
    }

    private static func trimLeadingPunctuation(_ token: String) -> (trimmed: String, rest: String) {
        var rest = Substring(token)
        var trimmed = ""
        while let first = rest.unicodeScalars.first, edgePunctuation.contains(first) {
            trimmed.append(Character(first))
            rest = rest.dropFirst()
        }
        return (trimmed, String(rest))
    }

    private static func trimTrailingPunctuation(_ token: String) -> (trimmed: String, rest: String) {
        var rest = Substring(token)
        var trimmed = ""
        while let last = rest.unicodeScalars.last, edgePunctuation.contains(last) {
            trimmed = String(Character(last)) + trimmed
            rest = rest.dropLast()
        }
        return (trimmed, String(rest))
    }
}
