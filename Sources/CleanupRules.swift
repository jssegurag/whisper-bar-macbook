import Foundation

/// Cuánto se limpia el dictado. El `rawValue` es lo que se escribe en
/// `defaults write com.user.WhisperBar cleanupLevel`, por eso está en español:
/// el usuario que abre la terminal no debería tener que traducir.
enum CleanupLevel: String, CaseIterable, Codable {
    case desactivado
    case conservador
    case completo

    /// Muletillas y repeticiones. Las dos reglas que solo borran ruido.
    var quitaRuido: Bool { self != .desactivado }

    /// Autocorrecciones y listas habladas. Reescriben estructura, no solo
    /// borran, así que solo entran en el nivel completo.
    var reescribeEstructura: Bool { self == .completo }

    var titulo: String {
        switch self {
        case .desactivado: return "Desactivado"
        case .conservador: return "Conservador"
        case .completo:    return "Completo"
        }
    }

    var explicacion: String {
        switch self {
        case .desactivado:
            return "El texto se pega tal como lo transcribió whisper."
        case .conservador:
            return "Quita muletillas entre pausas y palabras repetidas seguidas. No reescribe nada más."
        case .completo:
            return "Además resuelve autocorrecciones («mejor dicho…») y convierte enumeraciones habladas en listas."
        }
    }
}

/// Las tablas que usa `Cleaner`. Viven en un archivo JSON, no en el código:
/// la lista de muletillas es de las cosas que un usuario quiere ajustar sin
/// esperar a una versión nueva de la app.
///
/// Se busca en tres sitios, en este orden:
///
/// 1. `~/Library/Application Support/WhisperBar/cleanup-es.json` — la copia del
///    usuario. Existe para poder editar las tablas sin tocar el bundle firmado.
/// 2. El recurso dentro del bundle de la app.
/// 3. `Resources/cleanup-es.json` bajo el directorio actual — el repo, para el
///    arnés de tests y las herramientas, que no corren dentro de un bundle.
///
/// Si no aparece en ninguno, las tablas quedan vacías y el limpiador es inerte.
/// Es a propósito: sin tablas no hay forma de saber qué es muletilla, y borrar
/// a ciegas es exactamente el fallo que la regla de seguridad prohíbe.
struct CleanupRules: Codable, Equatable {

    /// Se quitan cuando abren frase o inciso.
    var fillersOpening: [String]
    /// Se quitan solo entre pausas: coma antes, coma o fin de oración después.
    var fillersPaused: [String]
    /// «mejor dicho», «perdón»… El hablante se corrige dentro de la oración.
    var selfCorrectionLocal: [String]
    /// «olvida lo anterior». Orden explícita de borrar lo dicho antes.
    var selfCorrectionTotal: [String]
    var listCardinals: [String]
    var listOrdinals: [String]
    /// Palabras que, tras un marcador, delatan que no era una lista.
    var listRejectNext: [String]

    enum CodingKeys: String, CodingKey {
        case fillersOpening      = "muletillasDeArranque"
        case fillersPaused       = "muletillasConPausa"
        case selfCorrectionLocal = "autocorreccionLocal"
        case selfCorrectionTotal = "autocorreccionTotal"
        case listCardinals       = "listaCardinales"
        case listOrdinals        = "listaOrdinales"
        case listRejectNext      = "listaRechazaSiguiente"
    }

    init(fillersOpening: [String] = [],
         fillersPaused: [String] = [],
         selfCorrectionLocal: [String] = [],
         selfCorrectionTotal: [String] = [],
         listCardinals: [String] = [],
         listOrdinals: [String] = [],
         listRejectNext: [String] = []) {
        self.fillersOpening      = fillersOpening
        self.fillersPaused       = fillersPaused
        self.selfCorrectionLocal = selfCorrectionLocal
        self.selfCorrectionTotal = selfCorrectionTotal
        self.listCardinals       = listCardinals
        self.listOrdinals        = listOrdinals
        self.listRejectNext      = listRejectNext
    }

    /// Cada lista se decodifica por separado y a falta de clave queda vacía: un
    /// archivo editado a mano al que le falta una sección sigue sirviendo para
    /// las demás, en vez de dejar la limpieza entera sin tablas.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fillersOpening      = try c.decodeIfPresent([String].self, forKey: .fillersOpening) ?? []
        fillersPaused       = try c.decodeIfPresent([String].self, forKey: .fillersPaused) ?? []
        selfCorrectionLocal = try c.decodeIfPresent([String].self, forKey: .selfCorrectionLocal) ?? []
        selfCorrectionTotal = try c.decodeIfPresent([String].self, forKey: .selfCorrectionTotal) ?? []
        listCardinals       = try c.decodeIfPresent([String].self, forKey: .listCardinals) ?? []
        listOrdinals        = try c.decodeIfPresent([String].self, forKey: .listOrdinals) ?? []
        listRejectNext      = try c.decodeIfPresent([String].self, forKey: .listRejectNext) ?? []
    }

    static let empty = CleanupRules()

    var isEmpty: Bool {
        fillersOpening.isEmpty && fillersPaused.isEmpty
            && selfCorrectionLocal.isEmpty && selfCorrectionTotal.isEmpty
            && listCardinals.isEmpty && listOrdinals.isEmpty
    }

    // MARK: - Carga

    static let fileName = "cleanup-es.json"

    static func load(from url: URL) throws -> CleanupRules {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CleanupRules.self, from: data)
    }

    /// Dónde puede estar el archivo, en orden de preferencia.
    static func searchPaths() -> [URL] {
        var paths: [URL] = []
        if let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            paths.append(support.appendingPathComponent("WhisperBar/\(fileName)"))
        }
        if let bundled = Bundle.main.url(forResource: "cleanup-es", withExtension: "json") {
            paths.append(bundled)
        }
        paths.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/\(fileName)"))
        return paths
    }

    // MARK: - Caché

    private static let lock = NSLock()
    private static var cached: (url: URL, modified: Date, rules: CleanupRules)?

    /// Las tablas vigentes. Se releen cuando el archivo cambia de fecha, para
    /// que editar la lista de muletillas no obligue a reiniciar la app.
    /// Devuelve `.empty` si no hay archivo o no se puede leer: la limpieza se
    /// apaga sola antes que adivinar.
    static func current() -> CleanupRules {
        lock.lock()
        defer { lock.unlock() }

        guard let url = searchPaths().first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            cached = nil
            return .empty
        }

        let modified = (try? FileManager.default
            .attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? nil
            ?? Date.distantPast

        if let hit = cached, hit.url == url, hit.modified == modified {
            return hit.rules
        }
        guard let rules = try? load(from: url) else {
            cached = nil
            return .empty
        }
        cached = (url, modified, rules)
        return rules
    }

    /// Para los tests: olvida lo cacheado.
    static func forgetCache() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
