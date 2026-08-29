import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Repaso del texto con el modelo de lenguaje **que ya trae macOS**.
///
/// Responde a la pregunta de por qué haría falta descargar un modelo para tener
/// algo más inteligente: en macOS 26 no hace falta. El sistema incluye uno, y la
/// app lo usa sin descargar un solo megabyte.
///
/// Es opcional y viene apagado: añade un par de segundos por dictado, y para la
/// mayoría de las transcripciones el corrector ortográfico ya basta.
///
/// **Orden deliberado:** esto corre *antes* del diccionario. Un modelo de
/// lenguaje tiende a «corregir» los términos propios del usuario hacia el español
/// estándar —fue la razón por la que se retiró el corrector con llama.cpp—, así
/// que el diccionario pasa después y los devuelve a su forma correcta.
enum SystemPolish {

    /// Por qué no se puede usar, en palabras que el usuario pueda accionar.
    enum Availability: Equatable {
        case available
        /// El Mac lo soporta pero Apple Intelligence está apagado.
        case needsAppleIntelligence
        /// macOS anterior al que incluye el modelo, o equipo no compatible.
        case unsupported(String)

        var isAvailable: Bool { self == .available }

        var message: String {
            switch self {
            case .available:
                return "Disponible. Usa el modelo que ya trae macOS, sin descargar nada."
            case .needsAppleIntelligence:
                return "Tu Mac lo soporta, pero Apple Intelligence está apagado. Se activa en Ajustes del Sistema."
            case .unsupported(let detalle):
                return "No disponible en este Mac: \(detalle)"
            }
        }
    }

    /// Instrucciones al modelo. Acotadas a propósito: cuanto más margen se le da,
    /// más reescribe, y aquí reescribir es un fallo, no una mejora.
    static let instructions = """
    Corriges transcripciones de voz. Devuelve EXACTAMENTE el mismo texto con la \
    ortografía, las tildes y la puntuación arregladas.

    Reglas estrictas:
    - No cambies ninguna palabra por un sinónimo.
    - No reformules, no resumas, no amplíes.
    - No añadas comentarios ni comillas.
    - No traduzcas: responde en el mismo idioma del texto.
    - Si el texto ya está bien, devuélvelo tal cual.
    """

    /// Cuánto se espera antes de rendirse y pegar el texto sin repasar. Vale más
    /// pegar algo imperfecto a tiempo que perfecto tarde.
    static let timeout: TimeInterval = 8

    static var availability: Availability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .needsAppleIntelligence
            case .unavailable(.modelNotReady):
                return .unsupported("el modelo aún se está preparando")
            case .unavailable(let razon):
                return .unsupported("\(razon)")
            @unknown default:
                return .unsupported("estado desconocido")
            }
        }
        return .unsupported("necesita macOS 26 o posterior")
        #else
        return .unsupported("esta compilación no incluye el modelo del sistema")
        #endif
    }

    /// Repasa el texto. Devuelve `nil` ante cualquier problema, y quien llama pega
    /// el original: un repaso que falla nunca debe costarle el dictado al usuario.
    static func polish(_ text: String) -> String? {
        guard shouldPolish(text), availability.isAvailable else { return nil }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let resultado = Box<String?>(nil)
            let listo = DispatchSemaphore(value: 0)
            Task {
                do {
                    let sesion = LanguageModelSession(instructions: instructions)
                    let respuesta = try await sesion.respond(to: text)
                    resultado.value = clean(respuesta.content, original: text)
                } catch {
                    resultado.value = nil
                }
                listo.signal()
            }
            guard listo.wait(timeout: .now() + timeout) == .success else { return nil }
            return resultado.value
        }
        #endif
        return nil
    }

    /// No vale la pena molestar al modelo con dos palabras, y el texto vacío no
    /// tiene nada que repasar.
    static func shouldPolish(_ text: String) -> Bool {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count >= 3
    }

    /// Descarta una respuesta que se salió del encargo.
    ///
    /// Un modelo pequeño a veces contesta con comillas, con un preámbulo, o
    /// reescribe media frase. Se compara la longitud contra el original: si se
    /// desvía mucho, dejó de corregir y empezó a redactar.
    static func clean(_ answer: String, original: String) -> String? {
        var texto = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.hasPrefix("\"") && texto.hasSuffix("\"") && texto.count > 1 {
            texto = String(texto.dropFirst().dropLast())
        }
        guard !texto.isEmpty else { return nil }

        let proporcion = Double(texto.count) / Double(max(original.count, 1))
        guard proporcion > 0.6, proporcion < 1.6 else { return nil }
        return texto
    }
}

/// Caja para sacar el resultado de la tarea asíncrona.
private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
