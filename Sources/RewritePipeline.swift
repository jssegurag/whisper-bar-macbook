import Foundation

/// Orden en que se reescribe una transcripción antes de pegarla.
///
/// Existe como tipo propio porque el orden **es** parte de la funcionalidad, no
/// un detalle de implementación, y enterrado como dos llamadas seguidas dentro de
/// AppDelegate nadie lo defiende ni lo prueba:
///
/// 1. **Diccionario** — corrige los términos que whisper oyó mal.
/// 2. **Snippets** — inserta los textos preconfigurados.
///
/// Los snippets van al final a propósito: su cuerpo es texto literal que el
/// usuario escribió. Si el diccionario corriera después, reescribiría la propia
/// firma del usuario.
struct RewritePipeline {

    static func apply(to text: String,
                      dictionary: [DictionaryEntry],
                      snippetRules: [PhraseRewriter.Rule]) -> String {
        applyReporting(to: text, dictionary: dictionary, snippetRules: snippetRules).text
    }

    /// Igual, pero dice qué términos del diccionario aplicaron, para el contador
    /// de usos.
    static func applyReporting(to text: String,
                               dictionary: [DictionaryEntry],
                               snippetRules: [PhraseRewriter.Rule])
        -> (text: String, dictionaryUsed: Set<String>) {

        let corrected = PhraseRewriter.applyReporting(
            to: text, index: DictionaryProcessor.buildIndex(from: dictionary))
        let expanded = PhraseRewriter.apply(to: corrected.text, rules: snippetRules)
        return (expanded, corrected.used)
    }
}
