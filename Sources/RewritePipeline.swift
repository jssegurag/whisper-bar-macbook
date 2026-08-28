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
        let corrected = DictionaryProcessor.apply(to: text, entries: dictionary)
        return PhraseRewriter.apply(to: corrected, rules: snippetRules)
    }
}
