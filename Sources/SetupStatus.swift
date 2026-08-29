import Foundation
import ApplicationServices

/// Resumen de si la app puede trabajar, y de qué le falta.
///
/// Reemplaza las seis filas de diagnóstico que ocupaban el menú. La regla del
/// rediseño es nombrar **qué** falta —«Falta el modelo de voz»— en lugar de
/// «configuración incompleta», que obligaba al usuario a ir a averiguarlo.
struct SetupStatus: Equatable {

    enum Level: Equatable {
        case ready
        /// Falta algo obligatorio: la app no puede transcribir.
        case missingRequired
    }

    let level: Level
    /// Texto de la fila de estado del menú.
    let title: String

    var needsAttention: Bool { level != .ready }

    /// Título de la fila del menú.
    ///
    /// Con todo en su sitio la fila se llama por su destino —«Configuración»—,
    /// porque «Todo listo» no dice a dónde lleva. Cuando falta algo se llama por
    /// el problema, que en ese momento importa más que el destino.
    var menuRowTitle: String {
        needsAttention ? title : "Configuración"
    }

    /// Orden de prioridad deliberado: sin motor no importa el modelo, así que se
    /// nombra primero el motor. Solo se reporta **una** cosa: la que hay que
    /// resolver ahora.
    static func evaluate(hasEngine: Bool,
                         hasModel: Bool,
                         hasAccessibility: Bool = true) -> SetupStatus {
        if !hasEngine {
            return SetupStatus(level: .missingRequired, title: "Falta el motor de voz")
        }
        if !hasModel {
            return SetupStatus(level: .missingRequired, title: "Falta el modelo de voz")
        }
        // Sin Accesibilidad la app transcribe y no pega en ningún sitio: el
        // usuario dicta, ve que no pasa nada, y no tiene forma de saber por qué.
        // Va después de motor y modelo porque sin ellos no hay nada que pegar.
        if !hasAccessibility {
            return SetupStatus(level: .missingRequired, title: "Falta el permiso de Accesibilidad")
        }
        return SetupStatus(level: .ready, title: "Todo listo")
    }

    static func current(_ config: Config = .shared) -> SetupStatus {
        evaluate(hasEngine: config.isWhisperCliValid,
                 hasModel: config.isModelValid,
                 hasAccessibility: AXIsProcessTrusted())
    }
}
