import Foundation

/// Mayúscula inicial y punto final. La última compuerta determinista que cruza
/// el texto antes de insertar los snippets.
///
/// ## Por qué existe, y por qué va donde va
///
/// Dictar en una terminal con la configuración pensada para el correo es
/// contraproducente: la mayúscula inicial y el punto final rompen el comando. Son
/// dos decisiones de formato, no de contenido, y hasta ahora la app no las
/// exponía: la capitalización solo ocurría dentro de `Cleaner`, por oración y
/// únicamente si esa oración ya había cambiado, y el punto final no lo tocaba
/// nada.
///
/// La etapa va **después de todo lo que puede reescribir el texto y antes de los
/// snippets**:
///
/// ```
/// whisper → repaso del sistema → limpieza → diccionario → ortografía → ACABADO → snippets
/// ```
///
/// Después del repaso del sistema porque ese modelo **arregla puntuación por
/// diseño**: devuelve la mayúscula y el punto que aquí se acaban de quitar. Si el
/// acabado corriera antes, el modelo desharía justo lo que el usuario pidió.
///
/// Antes de los snippets porque su cuerpo es texto literal que el usuario
/// escribió. Bajarle la inicial a una firma sería reescribírsela.
///
/// ## Simetría
///
/// `initialCapital` garantiza el estado pedido en las dos direcciones: `true`
/// asegura mayúscula, `false` asegura minúscula. Si `true` solo significara «no
/// tocar», el campo sería decorativo en el perfil que lo pide.
///
/// `trailingPeriod` no es simétrico, y es deliberado: `true` conserva lo que
/// venga, nunca añade un punto que el hablante no dijo. Añadirlo exigiría decidir
/// si la frase terminó, y equivocarse ahí escribe en el texto del usuario.
enum TextFinish {

    /// Aplica las dos reglas. `protected` recibe la misma lista que protege a
    /// `Cleaner`: ni la mayúscula ni la minúscula pueden estropear un término del
    /// usuario —«iPhone» no se convierte en «IPhone», «DocFly» no baja a
    /// «docFly»—.
    static func apply(_ text: String,
                      initialCapital: Bool,
                      trailingPeriod: Bool,
                      protected: Cleaner.Guard = .none) -> String {
        var out = text
        if !trailingPeriod { out = removingTrailingPeriod(out) }
        out = withInitial(out, uppercase: initialCapital, protected: protected)
        return out
    }

    // MARK: - Punto final

    /// Quita **un** punto final, y solo si es un punto de verdad.
    ///
    /// Los puntos suspensivos se respetan: quitarles uno los convierte en otra
    /// cosa, y eso es el falso positivo que la regla de seguridad del proyecto
    /// prohíbe. La exclamación y la interrogación tampoco se tocan — el ajuste
    /// habla del punto, no de todo signo terminal.
    private static func removingTrailingPeriod(_ text: String) -> String {
        guard let last = text.lastIndex(where: { !$0.isWhitespace }),
              text[last] == "." else { return text }
        // Un punto precedido de otro punto es una elipsis, no un final. El orden
        // importa: `index(before:)` sobre el primer índice es un error fatal, y
        // un texto que es solo «.» lo alcanza.
        if last > text.startIndex, text[text.index(before: last)] == "." { return text }
        // El espacio que sigue es formato del usuario y sobrevive.
        return text.replacingCharacters(in: last...last, with: "")
    }

    // MARK: - Mayúscula inicial

    /// La **primera letra**, no el primer carácter: el español abre con «¿» y
    /// «¡», y el dictado llega entrecomillado más veces de las que parece.
    private static func withInitial(_ text: String,
                                    uppercase: Bool,
                                    protected: Cleaner.Guard) -> String {
        guard let i = text.firstIndex(where: { $0.isLetter }) else { return text }
        let letra = text[i]
        guard uppercase ? letra.isLowercase : letra.isUppercase else { return text }
        guard !protected.covers(Cleaner.phraseKey(word(in: text, from: i))) else { return text }
        let cambiada = uppercase ? letra.uppercased() : letra.lowercased()
        return text.replacingCharacters(in: i...i, with: cambiada)
    }

    /// La palabra que empieza en `start`, para poder preguntarle a la lista de
    /// protegidos si es un término del usuario.
    private static func word(in text: String, from start: String.Index) -> String {
        let end = text[start...].firstIndex { !$0.isLetter && !$0.isNumber } ?? text.endIndex
        return String(text[start..<end])
    }
}
