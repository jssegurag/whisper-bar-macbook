import Foundation

/// Quita las frases que whisper **inventa** cuando el audio es silencio.
///
/// No es un fallo del modelo ni una fuga de datos, y conviene dejarlo escrito
/// porque asusta al verlo: whisper se entrenó con 680.000 horas de audio de
/// internet, buena parte subtítulos de YouTube. Ante silencio tiene que predecir
/// algo, y lo más probable que aprendió que sigue a un silencio es la despedida
/// de un vídeo. Se reproduce en cualquier máquina, sin red, con un WAV de
/// silencio digital absoluto:
///
///     whisper-cli -m ggml-large-v3.bin -l es --no-timestamps -f silencio.wav
///     →  Gracias por ver el video.
///
/// Aparece al **final** del dictado porque ahí es donde queda la cola de silencio
/// entre que el usuario deja de hablar y suelta la tecla.
///
/// ## La regla de seguridad
///
/// La misma que en `Cleaner`, y por el mismo motivo: un falso negativo deja una
/// frase de más que el usuario borra en dos segundos; un falso positivo **le come
/// una frase suya** y puede que no lo note hasta después de enviarla.
///
/// De ahí las dos decisiones que definen este archivo:
///
/// - **Coincidencia exacta de la línea completa**, normalizada. Nunca por
///   prefijo. La primera versión de esto —en `StreamingTranscriber`— comparaba
///   con `hasPrefix` sobre una lista que incluía «gracias» a secas, así que
///   borraba «Gracias por el reporte, lo reviso mañana» entera.
/// - **Solo se descarta la cola.** Una frase de la lista en mitad del dictado se
///   respeta: ahí el usuario estaba hablando.
///
/// Y se compara **por oración, no por línea**: whisper encadena varias en el
/// mismo renglón —«¡gracias por ver el video! ¡Suscríbete al canal!»— y mirando
/// la línea entera no coincide ninguna de las dos.
enum HallucinationFilter {

    // MARK: - Decisión

    /// Normaliza igual que el resto del pipeline: minúsculas, sin tildes, sin
    /// signos. Así «¡Gracias por ver el video!» y «Gracias por ver el vídeo.»
    /// caen las dos en la misma clave — la versión anterior no reconocía la
    /// primera, que es justo la que reportó el usuario.
    static func matches(_ line: String, phrases: Set<String>) -> Bool {
        guard !phrases.isEmpty else { return false }
        let key = Cleaner.phraseKey(line)
        guard !key.isEmpty else { return false }
        return phrases.contains(key)
    }

    /// Corta el texto en oraciones, conservando cada una tal cual.
    ///
    /// Hace falta porque whisper encadena varias alucinaciones en una sola
    /// línea: «¡gracias por ver el video! ¡Suscríbete al canal!» son dos frases
    /// conocidas, y comparando la línea entera no coincide ninguna.
    static func sentences(_ text: String) -> [String] {
        var trozos: [String] = []
        var actual = ""
        let chars = Array(text)

        for (i, ch) in chars.enumerated() {
            if ch.isNewline {
                if !actual.trimmingCharacters(in: .whitespaces).isEmpty { trozos.append(actual) }
                actual = ""
                continue
            }
            actual.append(ch)
            guard ch == "." || ch == "!" || ch == "?" || ch == "…" else { continue }
            // Solo corta si detrás viene un espacio o el final. Un punto pegado
            // a lo siguiente no cierra oración: es «Amara.org», «3.5», «etc.».
            // Con el corte ingenuo, la firma de Amara se partía en dos y dejaba
            // de reconocerse — que es justo la alucinación más repetida.
            let siguiente = i + 1 < chars.count ? chars[i + 1] : " "
            guard siguiente.isWhitespace else { continue }
            trozos.append(actual)
            actual = ""
        }
        if !actual.trimmingCharacters(in: .whitespaces).isEmpty { trozos.append(actual) }
        return trozos
    }

    /// Quita las oraciones alucinadas **del final** y devuelve el resto intacto.
    ///
    /// Dos niveles de confianza, y la diferencia importa:
    ///
    /// - `phrases` son inequívocas —«gracias por ver el video», la firma de
    ///   Amara.org—. Nadie las dicta en serio, así que basta una para descartarla.
    /// - `ambiguous` las alucina whisper igual, pero un humano también las dice:
    ///   «Buen trabajo hoy. Gracias a todos.» es una despedida normal. Solo se
    ///   descartan si en la misma cola hay **al menos una inequívoca**.
    ///
    /// Eso es lo que distingue una ráfaga alucinada —que llega en bloque, con la
    /// firma de Amara o el «suscríbete» delatándola— de una despedida de verdad,
    /// que va sola.
    /// Las oraciones que sobreviven, o **nil si no hay nada que quitar**.
    ///
    /// Devolver nil en vez del texto no es un detalle: quien llama sabe cómo
    /// quiere unir lo suyo, y así una entrada que el filtro no toca se devuelve
    /// exactamente como entró. Cuando esto devolvía el texto ya reensamblado,
    /// `cleanOutput` empezó a soltar los segmentos separados por saltos de línea
    /// en vez de por espacios — una regresión silenciosa en dictados que no
    /// tenían ninguna alucinación.
    static func keptSentences(_ text: String,
                              phrases: Set<String>,
                              ambiguous: Set<String> = []) -> [String]? {
        guard !phrases.isEmpty || !ambiguous.isEmpty, !text.isEmpty else { return nil }
        let trozos = sentences(text)

        // Se recorre hacia atrás hasta la primera oración que no es candidata.
        var fin = trozos.count
        var inequivocas = 0
        while fin > 0 {
            let trozo = trozos[fin - 1]
            if matches(trozo, phrases: phrases) {
                inequivocas += 1
            } else if !matches(trozo, phrases: ambiguous) {
                break
            }
            fin -= 1
        }
        guard fin < trozos.count else { return nil }

        // Con una inequívoca delatando la cola, se va entera.
        // Si no la hay, queda el caso del dictado que es SOLO despedidas: dos o
        // más oraciones y ninguna con contenido. Eso no lo dicta nadie, es un
        // dictado sin habla, y se descarta también.
        //
        // El límite está en dos a propósito. Con una sola —«Gracias.»— se
        // respeta: es una respuesta corta perfectamente normal. Y el riesgo que
        // queda es de los baratos: si alguien dictara «Muchas gracias a todos.
        // Hasta la próxima.» y no se pegara nada, lo ve al instante. Lo que no
        // podemos permitirnos es borrar una frase **dentro** de un texto largo,
        // que es lo que nadie revisa.
        let todoConocido = fin == 0 && trozos.count >= 2
        guard inequivocas > 0 || todoConocido else { return nil }

        return trozos[0..<fin]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Igual, uniendo con espacio y devolviendo el texto intacto si no hay nada
    /// que quitar.
    static func strip(_ text: String, phrases: Set<String>, ambiguous: Set<String> = []) -> String {
        guard let kept = keptSentences(text, phrases: phrases, ambiguous: ambiguous) else {
            return text
        }
        return kept.joined(separator: " ")
    }

    // MARK: - Tablas

    /// Las frases normalizadas y listas para comparar.
    /// Vacío si no hay archivo: sin lista no se descarta nada, que es la única
    /// respuesta segura — igual que en `CleanupRules`.
    static func phrases() -> Set<String> {
        Set(tables().frases.map(Cleaner.phraseKey).filter { !$0.isEmpty })
    }

    /// Las que solo cuentan acompañadas de una inequívoca.
    static func ambiguousPhrases() -> Set<String> {
        Set(tables().frasesAmbiguas.map(Cleaner.phraseKey).filter { !$0.isEmpty })
    }

    struct Tables: Codable {
        var frases: [String]
        var frasesAmbiguas: [String]

        init(frases: [String] = [], frasesAmbiguas: [String] = []) {
            self.frases = frases
            self.frasesAmbiguas = frasesAmbiguas
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            frases         = try c.decodeIfPresent([String].self, forKey: .frases) ?? []
            frasesAmbiguas = try c.decodeIfPresent([String].self, forKey: .frasesAmbiguas) ?? []
        }
    }

    static let fileName = "hallucinations.json"

    static func load(from url: URL) throws -> Tables {
        try JSONDecoder().decode(Tables.self, from: Data(contentsOf: url))
    }

    /// Mismo orden de búsqueda que `CleanupRules`: la copia del usuario, el
    /// recurso del bundle, y el repo para tests y herramientas.
    static func searchPaths() -> [URL] {
        var paths: [URL] = []
        if let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            paths.append(support.appendingPathComponent("WhisperBar/\(fileName)"))
        }
        if let bundled = Bundle.main.url(forResource: "hallucinations", withExtension: "json") {
            paths.append(bundled)
        }
        paths.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/\(fileName)"))
        return paths
    }

    private static let lock = NSLock()
    private static var cached: (url: URL, modified: Date, tables: Tables)?

    /// Se relee cuando cambia la fecha del archivo: editar la lista no obliga a
    /// reiniciar la app.
    static func tables() -> Tables {
        lock.lock()
        defer { lock.unlock() }

        guard let url = searchPaths().first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            cached = nil
            return Tables()
        }
        let modified = ((try? FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? nil)
            ?? Date.distantPast

        if let hit = cached, hit.url == url, hit.modified == modified {
            return hit.tables
        }
        guard let tables = try? load(from: url) else {
            cached = nil
            return Tables()
        }
        cached = (url, modified, tables)
        return tables
    }

    /// Para los tests: olvida lo cacheado.
    static func forgetCache() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
