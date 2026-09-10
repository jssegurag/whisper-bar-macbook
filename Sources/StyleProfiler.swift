import Foundation

/// Deduce cómo escribe el usuario a partir de textos suyos.
///
/// La alternativa era una lista de desplegables —formal/informal, largo/corto—,
/// y no sirve: nadie sabe describir su propio registro, y lo que elegiría de una
/// lista no se parece a cómo escribe de verdad. Cinco correos suyos dicen más
/// que cualquier formulario.
///
/// ## Las muestras no se guardan
///
/// Se usan para deducir y se descartan. Lo que persiste es el párrafo derivado.
/// Eso reduce la exposición de verdad, más que cualquier aviso: aunque el
/// usuario ignore la advertencia y pegue un correo con datos de un cliente, lo
/// que queda en disco es «escribe frases cortas y cierra con “quedo atento”».
///
/// El aviso sigue estando, porque las muestras sí pasan por el modelo —local,
/// pero pasan—.
enum StyleProfiler {

    /// Cuántos textos hacen falta. Con menos, el modelo describe *ese* texto en
    /// vez del estilo de quien lo escribió.
    static let minimumSamples = 5

    /// Cuánto puede ocupar la respuesta. Es un párrafo, no un ensayo.
    static let maxTokens = 320

    // MARK: - Las muestras

    struct Samples: Equatable {
        let count: Int
        let characters: Int
        /// Aproximación: en español ronda los cuatro caracteres por token. No
        /// hace falta precisión, solo saber si nos vamos a pasar.
        var estimatedTokens: Int { characters / 4 }
    }

    enum Problem: Error, Equatable {
        case tooFew(found: Int)
        case tooLong(estimatedTokens: Int, fits: Int)

        var message: String {
            switch self {
            case .tooFew(let n):
                let plural = n == 1 ? "texto" : "textos"
                return "Pega al menos \(StyleProfiler.minimumSamples) textos separados por una línea en blanco. "
                     + "Llevas \(n) \(plural)."
            case .tooLong(let tokens, let fits):
                return "Son demasiado largos para el contexto configurado "
                     + "(unas \(tokens) palabras-token frente a \(fits)). Quita alguno, "
                     + "o sube el contexto en los ajustes de abajo."
            }
        }
    }

    /// Los textos que pegó el usuario, separados por líneas en blanco.
    static func split(_ raw: String) -> [String] {
        raw.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// ¿Sirven estas muestras? Se comprueba **antes** de arrancar el modelo:
    /// hacer esperar veinte segundos para decir «pega más textos» es maltrato.
    static func inspect(_ raw: String, contextSize: Int) -> Result<Samples, Problem> {
        let textos = split(raw)
        guard textos.count >= minimumSamples else {
            return .failure(.tooFew(found: textos.count))
        }
        let caracteres = textos.reduce(0) { $0 + $1.count }
        let muestras = Samples(count: textos.count, characters: caracteres)

        // El contexto lo comparten las muestras, el encargo y la respuesta. Se
        // reserva la mitad para no truncar en silencio, que daría un perfil malo
        // sin decir por qué.
        let caben = max(256, contextSize / 2)
        guard muestras.estimatedTokens <= caben else {
            return .failure(.tooLong(estimatedTokens: muestras.estimatedTokens, fits: caben))
        }
        return .success(muestras)
    }

    // MARK: - El encargo

    static func systemPrompt() -> String {
        [
            "Analiza los textos del usuario y describe CÓMO ESCRIBE, en español.",
            "Devuelve un solo párrafo, de 40 a 80 palabras, en segunda persona («escribes…»).",
            "Fíjate en: registro (formal o cercano), longitud de las frases, saludos y despedidas habituales, si usa emojis, si tutea o trata de usted, y muletillas propias.",
            "NO resumas de qué tratan los textos. NO menciones nombres, empresas, direcciones ni datos concretos que aparezcan en ellos.",
            "No expliques lo que vas a hacer: devuelve solo la descripción.",
        ].joined(separator: "\n")
    }

    // MARK: - La respuesta

    /// El párrafo derivado, o nil si el modelo devolvió algo inservible.
    /// Reutiliza la limpieza del modo agente: el problema es el mismo, un modelo
    /// pequeño que saluda antes de obedecer.
    static func clean(_ raw: String) -> String? {
        guard let texto = AgentComposer.clean(raw) else { return nil }
        // Un perfil de dos palabras no describe nada; es el modelo fallando.
        guard texto.split(separator: " ").count >= 8 else { return nil }
        return texto
    }

    // MARK: - Deducción

    enum Failure: Error, Equatable {
        case samples(Problem)
        case unavailable(String)
        case unusable

        var message: String {
            switch self {
            case .samples(let p):        return p.message
            case .unavailable(let d):    return d
            case .unusable:
                return "El modelo no devolvió una descripción usable. Prueba con otros textos."
            }
        }
    }

    static func deduce(from raw: String,
                       contextSize: Int,
                       ask: (String, String) -> Result<String, LocalLLM.AskError>)
        -> Result<String, Failure> {

        switch inspect(raw, contextSize: contextSize) {
        case .failure(let problema):
            return .failure(.samples(problema))
        case .success:
            let textos = split(raw)
            let cuerpo = textos.enumerated()
                .map { "--- Texto \($0.offset + 1) ---\n\($0.element)" }
                .joined(separator: "\n\n")
            switch ask(systemPrompt(), cuerpo) {
            case .failure(let e): return .failure(.unavailable(e.message))
            case .success(let bruto):
                guard let perfil = clean(bruto) else { return .failure(.unusable) }
                return .success(perfil)
            }
        }
    }
}
