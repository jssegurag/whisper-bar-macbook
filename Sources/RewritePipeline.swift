import Foundation

/// Orden en que se reescribe una transcripción antes de pegarla.
///
/// Existe como tipo propio porque el orden **es** parte de la funcionalidad, no
/// un detalle de implementación, y enterrado como cuatro llamadas seguidas
/// dentro de AppDelegate nadie lo defiende ni lo prueba:
///
/// 1. **Limpieza** — quita muletillas, repeticiones y autocorrecciones.
/// 2. **Diccionario** — corrige los términos que whisper oyó mal.
/// 3. **Ortografía** — tildes y erratas, con el corrector del sistema.
/// 4. **Snippets** — inserta los textos preconfigurados.
///
/// La limpieza va **primera** por dos razones. Trabaja sobre lo que se dijo, no
/// sobre lo ya reescrito: si el diccionario corriera antes, la limpieza tendría
/// que decidir sobre términos que el usuario no pronunció así. Y borrar antes
/// de corregir evita corregir texto que se va a ir de todos modos.
///
/// Los snippets van al final a propósito: su cuerpo es texto literal que el
/// usuario escribió. Si el diccionario corriera después, reescribiría la propia
/// firma del usuario — y la limpieza le quitaría las muletillas a una firma.
struct RewritePipeline {

    static func apply(to text: String,
                      cleanup: ((String) -> String)? = nil,
                      dictionary: [DictionaryEntry],
                      snippetRules: [PhraseRewriter.Rule],
                      finish: ((String) -> String)? = nil) -> String {
        applyReporting(to: text, cleanup: cleanup, dictionary: dictionary,
                       snippetRules: snippetRules, finish: finish).text
    }

    /// Igual, pero dice qué términos del diccionario aplicaron, para el contador
    /// de usos.
    static func applyReporting(to text: String,
                               cleanup: ((String) -> String)? = nil,
                               dictionary: [DictionaryEntry],
                               snippetRules: [PhraseRewriter.Rule],
                               spellFix: ((String) -> String)? = nil,
                               finish: ((String) -> String)? = nil)
        -> (text: String, dictionaryUsed: Set<String>) {

        // La limpieza va primero, sobre el texto tal como se dictó.
        let cleaned = cleanup.map { $0(text) } ?? text
        let corrected = PhraseRewriter.applyReporting(
            to: cleaned, index: DictionaryProcessor.buildIndex(from: dictionary))
        // La ortografía va DESPUÉS del diccionario: así los términos propios ya
        // están en su forma canónica —con mayúsculas— y el corrector los deja en
        // paz. Al revés, intentaría «arreglar» palabras que no conoce.
        let spelled = spellFix.map { $0(corrected.text) } ?? corrected.text
        // El acabado —mayúscula inicial y punto final— es la última compuerta
        // determinista. Va aquí y no antes porque el repaso con el modelo del
        // sistema arregla puntuación por diseño y desharía lo que se acaba de
        // decidir. Ver TextFinish.
        let finished = finish.map { $0(spelled) } ?? spelled
        // Y los snippets al final: su contenido es literal y nada debe tocarlo,
        // ni el diccionario, ni el corrector, ni el acabado.
        let expanded = PhraseRewriter.apply(to: finished, rules: snippetRules)
        return (expanded, corrected.used)
    }
}
