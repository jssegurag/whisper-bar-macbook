import Foundation

/// Una entrada del diccionario personalizado: la forma correcta de un término y
/// las formas con las que whisper suele equivocarse al oírlo.
struct DictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var canonical: String      // la forma que se escribe
    var variants: [String]     // las formas que whisper produce
    var isActive: Bool
    let createdAt: Date
    /// Cuántas veces ha corregido algo de verdad. Sirve para saber qué entradas
    /// sobran: un término con cero usos en meses probablemente no hacía falta.
    var usageCount: Int

    init(id: UUID = UUID(),
         canonical: String,
         variants: [String] = [],
         isActive: Bool = true,
         createdAt: Date = Date(),
         usageCount: Int = 0) {
        self.id         = id
        self.canonical  = canonical
        self.variants   = variants
        self.isActive   = isActive
        self.createdAt  = createdAt
        self.usageCount = usageCount
    }

    /// Los archivos guardados antes de que existiera el contador no lo traen.
    enum CodingKeys: String, CodingKey {
        case id, canonical, variants, isActive, createdAt, usageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decode(UUID.self, forKey: .id)
        canonical  = try container.decode(String.self, forKey: .canonical)
        variants   = try container.decode([String].self, forKey: .variants)
        isActive   = try container.decode(Bool.self, forKey: .isActive)
        createdAt  = try container.decode(Date.self, forKey: .createdAt)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
    }

    /// Todas las formas por las que esta entrada debe reconocerse. La canónica
    /// también cuenta: registrar "DocFly" ya corrige "docfly" y "DOC FLY".
    var allForms: [String] { [canonical] + variants }
}

/// Almacenamiento persistente del diccionario personalizado.
/// JSON en Application Support, mismo patrón que TranscriptionHistory.
class CustomDictionary {
    static let shared = CustomDictionary()

    enum DictionaryError: LocalizedError {
        case emptyCanonical
        case unreadableFile(String)

        var errorDescription: String? {
            switch self {
            case .emptyCanonical:
                return "La forma correcta no puede estar vacía."
            case .unreadableFile(let detail):
                return "No se pudo leer el archivo: \(detail)"
            }
        }
    }

    private let storageURL: URL
    private(set) var entries: [DictionaryEntry] = []

    /// `storageURL` es inyectable para que los tests no toquen el diccionario real
    /// del usuario en Application Support.
    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? CustomDictionary.defaultStorageURL()
        load()
    }

    private static func defaultStorageURL() -> URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            // Ver la nota en TranscriptionHistory: la carpeta conserva el nombre
            // interno para no obligar a migrar los datos del usuario.
            .appendingPathComponent("WhisperBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dictionary.json")
    }

    // MARK: - Consulta

    var activeEntries: [DictionaryEntry] { entries.filter { $0.isActive } }

    /// Entradas cuya canónica o alguna variante contiene `query`, ignorando
    /// mayúsculas y acentos.
    func search(_ query: String) -> [DictionaryEntry] {
        let needle = DictionaryProcessor.normalize(query)
        guard !needle.isEmpty else { return entries }
        return entries.filter { entry in
            entry.allForms.contains { DictionaryProcessor.normalize($0).contains(needle) }
        }
    }

    /// Entradas distintas de `excluding` que ya reclaman alguna de estas formas.
    /// La UI lo usa para avisar de precedencias antes de guardar.
    func entriesClaiming(_ forms: [String], excluding id: UUID? = nil) -> [DictionaryEntry] {
        let claimed = Set(forms.map { DictionaryProcessor.normalize($0) }.filter { !$0.isEmpty })
        return entries.filter { entry in
            guard entry.id != id else { return false }
            return entry.allForms.contains { claimed.contains(DictionaryProcessor.normalize($0)) }
        }
    }

    // MARK: - Mutación

    @discardableResult
    func add(canonical: String, variants: [String], isActive: Bool = true) throws -> DictionaryEntry {
        let clean = CustomDictionary.sanitize(canonical: canonical, variants: variants)
        guard !clean.canonical.isEmpty else { throw DictionaryError.emptyCanonical }
        let entry = DictionaryEntry(canonical: clean.canonical,
                                    variants:  clean.variants,
                                    isActive:  isActive)
        entries.append(entry)
        save()
        return entry
    }

    /// Actualiza conservando `id` y `createdAt`.
    func update(id: UUID, canonical: String, variants: [String], isActive: Bool) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let clean = CustomDictionary.sanitize(canonical: canonical, variants: variants)
        guard !clean.canonical.isEmpty else { throw DictionaryError.emptyCanonical }
        entries[index].canonical = clean.canonical
        entries[index].variants  = clean.variants
        entries[index].isActive  = isActive
        save()
    }

    func setActive(id: UUID, _ active: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isActive = active
        save()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// Suma un uso a las entradas cuyas formas canónicas aparecen en `canonicals`.
    /// Lo llama el pipeline tras corregir un dictado real.
    func recordUsage(of canonicals: Set<String>) {
        guard !canonicals.isEmpty else { return }
        var changed = false
        for index in entries.indices where canonicals.contains(entries[index].canonical) {
            entries[index].usageCount += 1
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Importar / exportar

    func export(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: url, options: .atomic)
    }

    /// Agrega las entradas del archivo. Las canónicas que ya existen no se
    /// duplican. Devuelve cuántas se agregaron. Si el archivo no es válido,
    /// lanza y el diccionario queda intacto.
    @discardableResult
    func importEntries(from url: URL) throws -> Int {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw DictionaryError.unreadableFile(error.localizedDescription) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let incoming = try? decoder.decode([DictionaryEntry].self, from: data) else {
            throw DictionaryError.unreadableFile("el contenido no es un diccionario de Gluffi")
        }

        let existing = Set(entries.map { DictionaryProcessor.normalize($0.canonical) })
        var added = 0
        for entry in incoming {
            let clean = CustomDictionary.sanitize(canonical: entry.canonical, variants: entry.variants)
            guard !clean.canonical.isEmpty,
                  !existing.contains(DictionaryProcessor.normalize(clean.canonical)) else { continue }
            entries.append(DictionaryEntry(canonical: clean.canonical,
                                           variants:  clean.variants,
                                           isActive:  entry.isActive))
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    // MARK: - Saneamiento

    /// Recorta espacios, descarta formas vacías, elimina variantes duplicadas y
    /// las que repiten la canónica.
    static func sanitize(canonical: String, variants: [String]) -> (canonical: String, variants: [String]) {
        let cleanCanonical = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set([DictionaryProcessor.normalize(cleanCanonical)])
        var cleanVariants: [String] = []
        for variant in variants {
            let trimmed = variant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = DictionaryProcessor.normalize(trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            cleanVariants.append(trimmed)
        }
        return (cleanCanonical, cleanVariants)
    }

    // MARK: - Persistencia

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([DictionaryEntry].self, from: data)) ?? []
    }
}
