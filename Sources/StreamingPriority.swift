import Foundation

/// Prioridad de la transcripción en vivo.
///
/// Antes la pestaña de Streaming pedía tres números en milisegundos —Step, Length
/// y Keep— que nadie puede ajustar sin saber cómo funciona whisper-stream por
/// dentro. Ahora se elige entre tres prioridades con nombre, y los números
/// quedan detrás de «Ajustar a mano» para quien sepa lo que hace.
enum StreamingPriority: String, CaseIterable, Identifiable {
    case fast = "fast"
    case balanced = "balanced"
    case accurate = "accurate"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:     return "Rápido"
        case .balanced: return "Equilibrado"
        case .accurate: return "Preciso"
        }
    }

    /// Qué gana y qué pierde. Sin esto la elección es a ciegas.
    var explanation: String {
        switch self {
        case .fast:
            return "El texto aparece casi al instante, con más erratas. Bien para tomar notas para ti."
        case .balanced:
            return "Un momento de retraso a cambio de bastante menos erratas. Es lo que conviene casi siempre."
        case .accurate:
            return "Escucha tramos más largos antes de decidir. El texto llega más tarde y mejor escrito."
        }
    }

    /// Los tres valores que whisper-stream recibe, en milisegundos.
    var parameters: (step: Int, length: Int, keep: Int) {
        switch self {
        case .fast:     return (step: 500,  length: 3000,  keep: 200)
        case .balanced: return (step: 1000, length: 6000,  keep: 400)
        case .accurate: return (step: 2000, length: 10000, keep: 800)
        }
    }

    /// Qué prioridad corresponde a unos valores dados. Sirve para que la UI
    /// muestre la prioridad correcta al abrir, y para detectar que el usuario
    /// tiene valores propios que no coinciden con ninguna.
    static func matching(step: Int, length: Int, keep: Int) -> StreamingPriority? {
        allCases.first { priority in
            let p = priority.parameters
            return p.step == step && p.length == length && p.keep == keep
        }
    }

    /// Nombres en español de los tres parámetros, con lo que hace cada uno.
    /// «Step», «Length» y «Keep» no significan nada para quien no leyó el
    /// código de whisper-stream.
    static let parameterLabels = (
        step:   ("Cada cuánto revisa", "Con qué frecuencia aparece texto nuevo."),
        length: ("Cuánto audio escucha a la vez", "Tramos más largos se entienden mejor."),
        keep:   ("Cuánto recuerda del tramo anterior", "Evita cortar palabras entre tramos.")
    )
}
