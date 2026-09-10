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

    /// Descarta las líneas alucinadas **del final** y devuelve el resto intacto.
    ///
    /// Se recorre hacia atrás y se para en la primera línea que no es una
    /// alucinación: lo que hay antes es lo que el usuario dictó, aunque
    /// contenga una frase de la lista.
    static func stripTrailing(_ lines: [String], phrases: Set<String>) -> [String] {
        guard !phrases.isEmpty else { return lines }
        var fin = lines.count
        while fin > 0, matches(lines[fin - 1], phrases: phrases) {
            fin -= 1
        }
        return Array(lines[0..<fin])
    }

    // MARK: - Tablas

    /// Las frases normalizadas y listas para comparar.
    /// Vacío si no hay archivo: sin lista no se descarta nada, que es la única
    /// respuesta segura — igual que en `CleanupRules`.
    static func phrases() -> Set<String> {
        Set(tables().frases.map(Cleaner.phraseKey).filter { !$0.isEmpty })
    }

    struct Tables: Codable {
        var frases: [String]

        init(frases: [String] = []) { self.frases = frases }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            frases = try c.decodeIfPresent([String].self, forKey: .frases) ?? []
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
