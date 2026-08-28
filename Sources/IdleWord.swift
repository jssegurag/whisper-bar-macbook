import Foundation

/// La palabra que la píldora muestra en reposo.
///
/// En lugar de «Listo», una invitación a hablar. Y con una regla estricta contra
/// la distracción: **la palabra no cambia nunca mientras está a la vista.** Una
/// píldora que rota palabras delante de quien intenta trabajar es un anuncio.
///
/// Solo puede cambiar al volver a reposo **después de un dictado**, y con un
/// mínimo de 15 minutos desde el último cambio. Índice y momento se guardan, así
/// que reiniciar la app tampoco fuerza un cambio.
enum IdleWord {

    static let words = [
        "Dime", "Te escucho", "Cuéntame", "Aquí estoy",
        "Suéltalo", "Sin prisa", "Piensa alto", "Al oído",
    ]

    /// 15 minutos.
    static let minimumInterval: TimeInterval = 900

    static func word(at index: Int) -> String {
        words[((index % words.count) + words.count) % words.count]
    }

    /// Decide si rotar. Se llama **solo** al volver a reposo tras un dictado.
    ///
    /// - Returns: el índice a mostrar y si hubo cambio. Si no toca rotar,
    ///   devuelve el mismo índice.
    static func rotate(current: Int,
                       lastChange: Date?,
                       now: Date = Date(),
                       minimumInterval: TimeInterval = IdleWord.minimumInterval)
        -> (index: Int, changed: Bool) {

        guard let lastChange else {
            // Primera vez: se fija el momento sin cambiar la palabra, para que el
            // reloj empiece a contar desde el primer dictado.
            return (current, true)
        }
        guard now.timeIntervalSince(lastChange) >= minimumInterval else {
            return (current, false)
        }
        return ((current + 1) % words.count, true)
    }
}
