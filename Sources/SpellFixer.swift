import AppKit

/// Corrección ortográfica con el corrector del sistema.
///
/// macOS ya trae uno, offline y por idioma. Cubre lo que la gente espera de un
/// «corrector» —tildes y erratas— sin instalar un modelo de lenguaje de un
/// gigabyte que además tarda segundos y reescribe los términos propios del
/// usuario.
///
/// Es deliberadamente conservador: corregir de más es peor que no corregir. Si
/// una palabra sale mal y el usuario no lo nota, el texto queda peor de lo que
/// estaba.
enum SpellFixer {

    /// Decide si una sugerencia se aplica. Separado del corrector del sistema
    /// para poder probar la política sin depender del diccionario de macOS.
    static func shouldReplace(original: String, suggestion: String) -> Bool {
        guard !original.isEmpty, !suggestion.isEmpty,
              original.lowercased() != suggestion.lowercased() else { return false }

        // Nada con mayúsculas dentro ni cifras: nombres propios, siglas y
        // referencias no son erratas aunque el corrector no las conozca.
        guard original == original.lowercased(),
              !original.contains(where: \.isNumber) else { return false }

        // Una sugerencia que cambia el número de palabras está reinterpretando la
        // frase, no corrigiendo una errata.
        guard !suggestion.contains(" ") else { return false }

        // Y solo cambios pequeños: una tilde, una letra. Si hace falta reescribir
        // media palabra, probablemente el corrector no entendió de qué se habla.
        return distance(original.lowercased(), suggestion.lowercased()) <= 2
    }

    /// Distancia de edición, para acotar cuánto puede cambiar una palabra.
    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previa = Array(0...y.count)
        var actual = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            actual[0] = i
            for j in 1...y.count {
                let coste = x[i - 1] == y[j - 1] ? 0 : 1
                actual[j] = min(previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + coste)
            }
            swap(&previa, &actual)
        }
        return previa[y.count]
    }

    /// Corrige `text`. `protegidas` son las formas que nunca deben tocarse: los
    /// términos del diccionario del usuario y las frases de sus snippets.
    static func fix(_ text: String,
                    language: String,
                    protected: Set<String>,
                    checker: NSSpellChecker = .shared) -> String {
        guard !text.isEmpty else { return text }

        let idioma = spellCheckerLanguage(for: language)
        let protegidasNormalizadas = Set(protected.map { $0.lowercased() })
        var resultado = text
        var desde = 0

        // Se recorre de principio a fin, reemplazando sobre la marcha. Los rangos
        // se recalculan en cada vuelta porque una corrección puede cambiar la
        // longitud del texto.
        while desde < (resultado as NSString).length {
            let rango = checker.checkSpelling(of: resultado, startingAt: desde,
                                             language: idioma, wrap: false,
                                             inSpellDocumentWithTag: 0, wordCount: nil)
            guard rango.location != NSNotFound, rango.length > 0 else { break }

            let palabra = (resultado as NSString).substring(with: rango)
            desde = rango.location + rango.length

            guard !protegidasNormalizadas.contains(palabra.lowercased()) else { continue }
            guard let sugerencias = checker.guesses(forWordRange: rango, in: resultado,
                                                   language: idioma,
                                                   inSpellDocumentWithTag: 0),
                  let mejor = sugerencias.first,
                  shouldReplace(original: palabra, suggestion: mejor) else { continue }

            resultado = (resultado as NSString).replacingCharacters(in: rango, with: mejor)
            desde = rango.location + (mejor as NSString).length
        }
        return resultado
    }

    /// «auto» deja que el corrector use el idioma del sistema.
    static func spellCheckerLanguage(for code: String) -> String {
        code == "auto" || code.isEmpty ? NSSpellChecker.shared.language() : code
    }
}
