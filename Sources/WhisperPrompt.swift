import Foundation

/// Construye el *initial prompt* que se le pasa a whisper-cli.
///
/// whisper acepta un texto previo que sesga el reconocimiento: si tus términos
/// aparecen ahí, los **oye** bien desde el principio en lugar de que haya que
/// corregirlos después. Ataca la causa en vez del síntoma, y no cuesta ni un
/// archivo extra ni un segundo de latencia.
///
/// El diccionario sigue actuando como red de seguridad para lo que aun así se
/// oiga mal.
enum WhisperPrompt {

    /// whisper acepta hasta `n_text_ctx/2` tokens, que en los modelos grandes son
    /// 224. Se limita por caracteres, con un margen amplio: pasarse hace que
    /// whisper recorte por su cuenta y el recorte puede caer a mitad de un
    /// término, que es peor que dejarlo fuera.
    static let maxCharacters = 500

    /// Términos ordenados por utilidad demostrada: primero los que más han
    /// corregido de verdad. Cuando el diccionario no cabe entero, entran los que
    /// hacen falta, no los primeros alfabéticamente.
    static func terms(from entries: [DictionaryEntry]) -> [String] {
        entries
            .filter { $0.isActive }
            .sorted {
                $0.usageCount != $1.usageCount
                    ? $0.usageCount > $1.usageCount
                    : $0.canonical.localizedCaseInsensitiveCompare($1.canonical) == .orderedAscending
            }
            .map(\.canonical)
            .filter { !$0.isEmpty }
    }

    /// El prompt, o nil si no hay nada que sesgar.
    ///
    /// Se escribe como una frase natural y bien puntuada a propósito: whisper
    /// imita el estilo del prompt, así que un prompt con mayúsculas y puntos
    /// empuja a que la transcripción también las tenga.
    static func build(from entries: [DictionaryEntry],
                      limit: Int = maxCharacters) -> String? {
        let disponibles = terms(from: entries)
        guard !disponibles.isEmpty else { return nil }

        let prefijo = "Glosario: "
        let sufijo = "."
        var incluidos: [String] = []
        var longitud = prefijo.count + sufijo.count

        for termino in disponibles {
            let coste = termino.count + (incluidos.isEmpty ? 0 : 2)   // ", "
            guard longitud + coste <= limit else { break }
            incluidos.append(termino)
            longitud += coste
        }

        guard !incluidos.isEmpty else { return nil }
        return prefijo + incluidos.joined(separator: ", ") + sufijo
    }
}
