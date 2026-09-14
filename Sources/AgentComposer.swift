import Foundation

/// Convierte una orden dictada en el texto que el usuario quería escribir.
///
/// La diferencia con todo lo demás en la app: aquí **se pega algo que el usuario
/// no dijo**. Eso cambia dos reglas.
///
/// ## Los snippets van primero
///
/// En el resto del pipeline los snippets van al final, porque su contenido es
/// literal y nada debe reescribirlo. Aquí la orden **habla de** ellos —«diciendo
/// que este es mi correo»— en vez de contenerlos, así que si «mi correo» llegara
/// sin resolver el modelo escribiría «mi correo» tal cual, o se inventaría una
/// dirección.
///
/// El diccionario sigue yendo **después** del modelo, y eso no se toca: en la
/// validación de HU-004 el modelo reescribía «DocFly» y «Oriuno» por su cuenta.
///
/// ## Si falla, no se pega nada
///
/// En el resto de la app un fallo devuelve el texto original. Aquí el «original»
/// es la orden, y pegar «Redacta un correo para Juan…» dentro del correo a Juan
/// es un desastre visible. Por eso `compose` devuelve un error y nunca un
/// sustituto.
/// En qué está Gluffi: transcribiendo lo que dices, o redactando lo que pides.
///
/// **No se guarda entre sesiones, y es deliberado.** Un modo persistente
/// convierte un fallo visible en uno invisible: abres el portátil, dictas «llego
/// en diez minutos» sin mirar la píldora, y te sale un correo de cuatro párrafos
/// porque anoche te dejaste el agente puesto. Arrancar siempre en el modo seguro
/// cuesta un clic a quien vive en modo agente; lo contrario cuesta un correo
/// enviado a destiempo.
enum DictationIntent: String, CaseIterable {
    case transcribe
    case agent

    var title: String {
        switch self {
        case .transcribe: return "Transcribir"
        case .agent:      return "Redactar"
        }
    }

    /// El icono del interruptor. Sin etiqueta: el modo se lee en el color de
    /// toda la píldora, que es más visible que una palabra de diez puntos.
    var symbol: String {
        switch self {
        case .transcribe: return "textformat.abc"   // «AB»: sale tu texto tal cual
        case .agent:      return "sparkles"
        }
    }

    var help: String {
        switch self {
        case .transcribe: return "Transcribir lo que dices · pulsa para redactar lo que pides"
        case .agent:      return "Redactar lo que pides · pulsa para volver a transcribir"
        }
    }

    var toggled: DictationIntent { self == .transcribe ? .agent : .transcribe }
}

enum AgentComposer {

    enum Failure: Error, Equatable {
        /// El modelo no está configurado o no arrancó.
        case unavailable(String)
        /// Respondió, pero no se pudo usar.
        case unusable
        /// La orden venía vacía.
        case emptyOrder

        /// Lo que se le dice al usuario, con la voz de la app.
        var message: String {
            switch self {
            case .unavailable(let detalle): return detalle
            case .unusable, .emptyOrder:    return "Ups, no te entendí"
            }
        }
    }

    /// Cuántos tokens puede ocupar la redacción. El resto de la app usa 512, que
    /// se queda corto para un correo entero.
    static let maxTokens = 1024

    // MARK: - El encargo

    /// Lo que se le pide al modelo. En español, y con una sola instrucción
    /// innegociable: devolver el texto y nada más. Los modelos pequeños tienden
    /// a saludar antes de obedecer.
    static func systemPrompt(style: String) -> String {
        var partes = [
            "Eres el asistente de redacción de un usuario que dicta por voz.",
            "Recibes una orden y devuelves ÚNICAMENTE el texto final que el usuario quiere escribir.",
            "No expliques lo que vas a hacer, no saludes al usuario, no añadas comentarios ni comillas alrededor.",
            "No inventes datos que no estén en la orden: ni nombres, ni fechas, ni cifras, ni direcciones.",
            "Escribe en el mismo idioma de la orden.",
        ]
        let estilo = style.trimmingCharacters(in: .whitespacesAndNewlines)
        if !estilo.isEmpty {
            partes.append("Así escribe este usuario; imítalo: \(estilo)")
        }
        // Va al final a propósito: lo que el usuario pide esta vez manda sobre
        // cómo escribe normalmente.
        partes.append("Si la orden incluye indicaciones de tono o formato, tienen prioridad sobre lo anterior.")
        return partes.joined(separator: "\n")
    }

    // MARK: - La respuesta

    /// Quita lo que el modelo añade de su cosecha.
    ///
    /// No es paranoia: `SystemPolish` ya tuvo que hacer lo mismo. Un modelo
    /// pequeño responde «¡Claro! Aquí tienes el correo:» y luego el correo, o lo
    /// envuelve entero en comillas.
    static func clean(_ raw: String) -> String? {
        var texto = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return nil }

        // Un preámbulo típico ocupa su propia primera línea y termina en dos
        // puntos. Solo se quita si detrás queda algo: si no, era la respuesta.
        let lineas = texto.components(separatedBy: .newlines)
        if lineas.count > 1, let primera = lineas.first {
            let l = primera.trimmingCharacters(in: .whitespaces)
            let esPreambulo = l.hasSuffix(":") && l.count < 80
                && preambleHints.contains { l.lowercased().contains($0) }
            if esPreambulo {
                texto = lineas.dropFirst().joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Comillas que envuelven el texto entero.
        for (abre, cierra) in [("\"", "\""), ("«", "»"), ("'", "'")] {
            if texto.hasPrefix(abre), texto.hasSuffix(cierra), texto.count > 2 {
                texto = String(texto.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return texto.isEmpty ? nil : texto
    }

    private static let preambleHints = [
        "aquí tienes", "aqui tienes", "claro", "por supuesto", "este es",
        "aquí está", "aqui esta", "here is", "here's", "sure",
    ]

    // MARK: - Orquestación

    /// Resuelve los snippets de la orden y le pide al modelo el texto final.
    ///
    /// `ask` se inyecta para poder probar todo esto sin un modelo de 2,5 GB
    /// delante — igual que hacen las pruebas de `LocalLLM` con su servidor falso.
    static func compose(order: String,
                        style: String,
                        snippetRules: [PhraseRewriter.Rule],
                        ask: (String, String) -> Result<String, LocalLLM.AskError>)
        -> Result<String, Failure> {

        let limpia = order.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return .failure(.emptyOrder) }

        // Los snippets, antes de que el modelo lea la orden.
        let expandida = PhraseRewriter.apply(to: limpia, rules: snippetRules)

        switch ask(systemPrompt(style: style), expandida) {
        case .failure(let error):
            return .failure(.unavailable(error.message))
        case .success(let bruto):
            guard let texto = clean(bruto) else { return .failure(.unusable) }
            return .success(texto)
        }
    }
}
