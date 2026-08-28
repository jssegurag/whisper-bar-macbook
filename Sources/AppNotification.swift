import Foundation
import AVFoundation

/// Las notificaciones de Gluffi, con su acción.
///
/// Regla del rediseño: **ninguna notificación manda al usuario a buscar.** Antes
/// decían «abre el menú para ver el estado» o «abre Preferencias → Modelos», que
/// es delegarle al usuario el trabajo de encontrar el sitio. Y tres decían
/// «Error: …» seguido del mensaje del sistema, que rara vez explica qué hacer.
///
/// Cada caso trae título en lenguaje humano, causa probable y el botón que
/// resuelve. El contenido se construye con funciones puras para poder probarlo
/// sin lanzar notificaciones.
enum AppNotification {

    /// Botones. El identificador viaja en la respuesta de UNNotification.
    enum Action: String {
        case configure = "gluffi.configure"
        case retryRecording = "gluffi.retryRecording"
        case update = "gluffi.update"
        case dismiss = "gluffi.dismiss"

        var title: String {
            switch self {
            case .configure:      return "Configurar"
            case .retryRecording: return "Reintentar"
            case .update:         return "Actualizar"
            case .dismiss:        return "Luego"
            }
        }
    }

    struct Content: Equatable {
        let title: String
        let body: String
        let actions: [Action]
        /// Agrupa por tipo: una notificación nueva del mismo tipo reemplaza la
        /// anterior en vez de apilarse.
        let identifier: String

        var categoryIdentifier: String {
            "gluffi.category." + actions.map(\.rawValue).joined(separator: ".")
        }
    }

    // MARK: - Construcción del contenido

    /// Falta algo obligatorio. Nombra qué falta y lleva a resolverlo.
    static func setupIncomplete(_ status: SetupStatus) -> Content {
        Content(
            title: status.title,
            body: "Gluffi no puede transcribir hasta que lo resuelvas. Toma un minuto.",
            actions: [.configure, .dismiss],
            identifier: "setup")
    }

    static func updateAvailable(package: String, version: String) -> Content {
        Content(
            title: "Nueva versión de \(package)",
            body: "Hay \(version) disponible. Se actualiza en segundo plano.",
            actions: [.update, .dismiss],
            identifier: "update")
    }

    /// No se pudo grabar. La causa probable se deduce del permiso y del
    /// dispositivo, en lugar de repetir el mensaje del sistema.
    static func recordingFailed(permission: AVAuthorizationStatus,
                                hasInputDevice: Bool,
                                systemMessage: String) -> Content {
        let cause: String
        var actions: [Action] = [.retryRecording]
        switch permission {
        case .denied, .restricted:
            cause = "Gluffi no tiene permiso para usar el micrófono. Se concede en Ajustes del Sistema → Privacidad y seguridad → Micrófono."
            actions = [.configure]
        case .notDetermined:
            cause = "Falta conceder el permiso del micrófono. Vuelve a intentarlo y acepta el diálogo."
        default:
            if !hasInputDevice {
                cause = "No hay ningún micrófono conectado."
                actions = []
            } else {
                cause = "Puede que otra app esté usando el micrófono. Ciérrala y vuelve a intentarlo."
            }
        }
        return Content(title: "No se pudo grabar",
                       body: cause.isEmpty ? systemMessage : cause,
                       actions: actions,
                       identifier: "recording")
    }

    /// Falló la transcripción. Cada error del Transcriber tiene una causa y una
    /// salida distintas: repetirlas todas como «Error: …» era desperdiciarlas.
    static func transcriptionFailed(_ error: Error) -> Content? {
        guard let known = error as? Transcriber.TranscriberError else {
            return Content(title: "No se pudo transcribir",
                           body: error.localizedDescription,
                           actions: [.configure],
                           identifier: "transcription")
        }
        switch known {
        case .cancelled:
            // Cancelar fue voluntario: avisarlo sería ruido.
            return nil
        case .invalidConfig:
            return Content(title: "Falta configurar el motor de voz",
                           body: "Gluffi no encontró whisper-cli o el modelo. Se arregla en un paso.",
                           actions: [.configure],
                           identifier: "transcription")
        case .timeout(let seconds):
            return Content(title: "La transcripción tardó demasiado",
                           body: "Se cortó a los \(seconds) s. Un modelo más pequeño transcribe mucho más rápido.",
                           actions: [.configure],
                           identifier: "transcription")
        case .processFailed(_, let stderr):
            let detail = stderr.split(separator: "\n").last.map(String.init) ?? ""
            return Content(title: "El motor de voz falló",
                           body: detail.isEmpty ? "whisper-cli terminó con error." : detail,
                           actions: [.configure],
                           identifier: "transcription")
        }
    }

    static func llmFailed(_ message: String) -> Content {
        Content(title: "Se pegó el texto sin corregir",
                body: "La corrección con IA falló, así que Gluffi pegó la transcripción tal cual. \(message)",
                actions: [.configure],
                identifier: "llm")
    }

    static func translationFailed(_ message: String) -> Content {
        Content(title: "No se pudo traducir",
                body: message,
                actions: [.configure],
                identifier: "translation")
    }

    /// Un snippet sensible no se pudo descifrar. La causa casi siempre es la
    /// misma: la firma del binario cambió y el Llavero pide permiso otra vez.
    static func snippetUnreadable(name: String) -> Content {
        Content(title: "No se pudo leer «\(name)»",
                body: "El Llavero no dio acceso a su contenido cifrado. Si acabas de recompilar Gluffi, hay que autorizarlo de nuevo.",
                actions: [.configure],
                identifier: "snippet")
    }

    /// Resultado de una acción por voz: informativo, sin botones.
    static func actionResult(_ message: String) -> Content {
        Content(title: "Gluffi", body: message, actions: [], identifier: "voiceAction")
    }
}
