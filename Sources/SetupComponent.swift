import Foundation

/// Los cuatro componentes que Gluffi necesita, con su estado.
///
/// Reemplaza las seis filas de diagnóstico del menú y las cuatro pestañas de
/// Preferencias que pedían rutas de binarios. La diferencia no es cosmética:
/// aquí cada fila dice **qué es**, **si es obligatorio** y **cómo resolverlo**,
/// en vez de un ✅ o un ❌ sin salida.
struct SetupComponent: Identifiable, Equatable {

    enum Kind: String, Equatable {
        case engine      // whisper-cli
        case model       // el .bin de whisper
        case llm         // llama-completion + modelo .gguf
        case streaming   // whisper-stream
    }

    enum State: Equatable {
        case ready
        /// Falta y es obligatorio: la app no puede transcribir.
        case missingRequired
        /// Falta y es opcional: la app funciona sin él.
        case missingOptional
    }

    let kind: Kind
    let title: String
    let purpose: String
    /// Ruta o mensaje que describe qué hay hoy.
    let detail: String
    let state: State

    var id: String { kind.rawValue }
    var isRequired: Bool { state != .missingOptional }

    /// Etiqueta corta bajo el título: «obligatorio» / «opcional» / «falta esto».
    var label: String {
        switch state {
        case .missingRequired: return "falta esto"
        case .missingOptional: return "opcional"
        case .ready:           return kind == .engine || kind == .model ? "obligatorio" : "opcional"
        }
    }
}

/// Estado completo de la instalación: los cuatro componentes y el resumen que va
/// en el encabezado de la ventana.
struct SetupSummary: Equatable {
    let components: [SetupComponent]

    var missingRequired: Int { components.filter { $0.state == .missingRequired }.count }
    var missingOptional: Int { components.filter { $0.state == .missingOptional }.count }
    var ready: Int { components.filter { $0.state == .ready }.count }
    var canTranscribe: Bool { missingRequired == 0 }

    /// Encabezado. Nombra cuánto falta en vez de decir «configuración incompleta».
    var headline: String {
        canTranscribe ? "Gluffi está listo" : "Gluffi está casi listo"
    }

    var subhead: String {
        let total = components.count
        if missingRequired > 0 {
            let falta = "Falta \(missingRequired) de \(total)."
            return ready > 0 ? "\(falta) Los otros \(ready) ya están listos." : falta
        }
        if missingOptional > 0 {
            return missingOptional == 1
                ? "Listo para transcribir. Queda 1 mejora opcional sin configurar."
                : "Listo para transcribir. Quedan \(missingOptional) mejoras opcionales sin configurar."
        }
        return "Los \(total) componentes están en su sitio."
    }

    static func evaluate(engine: Bool, model: Bool,
                         llmEnabled: Bool, llm: Bool,
                         streaming: Bool) -> SetupSummary {
        SetupSummary(components: [
            SetupComponent(
                kind: .engine,
                title: "Motor de voz",
                purpose: "Convierte tu voz en texto, sin salir de este Mac.",
                detail: engine ? Config.shared.whisperCliPath : "whisper-cli no está instalado",
                state: engine ? .ready : .missingRequired),
            SetupComponent(
                kind: .model,
                title: "Modelo de voz",
                purpose: "El archivo que el motor usa para entender lo que dices. Formato .bin.",
                detail: model ? Config.shared.modelPath : "todavía no hay ninguno",
                state: model ? .ready : .missingRequired),
            SetupComponent(
                kind: .llm,
                title: "Modelo de lenguaje",
                // Ya no corrige texto: eso lo hace el corrector del sistema, gratis.
                // Queda solo para lo que de verdad necesita entender lenguaje.
                purpose: "Solo para los comandos por voz y para traducir a idiomas distintos del inglés. "
                       + "Necesita un archivo .gguf, distinto del modelo de voz: aquel entiende audio, este escribe texto. "
                       + "Si no usas comandos por voz, no hace falta.",
                detail: llm ? Config.shared.llmModelPath
                            : (llmEnabled ? "activada, pero falta el modelo"
                                          : "sin configurar"),
                state: llm ? .ready : .missingOptional),
            SetupComponent(
                kind: .streaming,
                title: "Transcripción en vivo",
                purpose: "Muestra el texto mientras hablas, en una ventana flotante.",
                detail: streaming ? Config.shared.whisperStreamPath
                                  : "whisper-stream no está instalado",
                state: streaming ? .ready : .missingOptional),
        ])
    }

    static func current(_ config: Config = .shared) -> SetupSummary {
        evaluate(engine: config.isWhisperCliValid,
                 model: config.isModelValid,
                 llmEnabled: config.llmEnabled,
                 llm: config.isLlmCliValid && config.isLlmModelValid,
                 streaming: config.isWhisperStreamValid)
    }
}
