import Foundation

/// Corrección del diccionario personalizado. Capa delgada sobre PhraseRewriter,
/// que es el motor compartido con los snippets por voz.
///
/// Existe como tipo propio para que el diccionario no dependa de cómo se
/// modelan las reglas del motor, y para conservar su API y sus tests.
struct DictionaryProcessor {

    typealias Index = PhraseRewriter.Index

    /// Para comparar: minúsculas, sin acentos, espacios colapsados.
    static func normalize(_ text: String) -> String {
        PhraseRewriter.normalize(text)
    }

    /// Reglas de las entradas activas. La forma canónica también es objetivo de
    /// coincidencia: registrar "DocFly" ya corrige "docfly" y "DOC FLY".
    static func rules(from entries: [DictionaryEntry]) -> [PhraseRewriter.Rule] {
        entries.compactMap { entry in
            guard entry.isActive else { return nil }
            let canonical = entry.canonical.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else { return nil }
            return PhraseRewriter.Rule(phrases: entry.allForms, replacement: canonical)
        }
    }

    static func buildIndex(from entries: [DictionaryEntry]) -> Index {
        PhraseRewriter.buildIndex(from: rules(from: entries))
    }

    static func apply(to text: String, entries: [DictionaryEntry]) -> String {
        PhraseRewriter.apply(to: text, index: buildIndex(from: entries))
    }

    static func apply(to text: String, index: Index) -> String {
        PhraseRewriter.apply(to: text, index: index)
    }
}
