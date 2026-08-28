import Foundation
import CryptoKit

/// Un snippet: un texto preconfigurado que se inserta al pronunciar uno de sus
/// disparadores.
struct Snippet: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String            // etiqueta corta; es lo que sale en el menú
    var triggers: [String]      // frases que lo invocan
    var isSensitive: Bool       // cuerpo cifrado y autenticación para verlo
    var isActive: Bool
    let createdAt: Date

    /// Cuerpo en claro. Nil cuando el snippet es sensible.
    var plainBody: String?
    /// Cuerpo cifrado (AES-GCM). Nil cuando el snippet no es sensible.
    var sealedBody: Data?

    enum CodingKeys: String, CodingKey {
        case id, name, triggers, isSensitive, isActive, createdAt
        case plainBody = "body"
        case sealedBody
    }

    init(id: UUID = UUID(),
         name: String,
         triggers: [String],
         isSensitive: Bool = false,
         isActive: Bool = true,
         createdAt: Date = Date(),
         plainBody: String? = nil,
         sealedBody: Data? = nil) {
        self.id = id
        self.name = name
        self.triggers = triggers
        self.isSensitive = isSensitive
        self.isActive = isActive
        self.createdAt = createdAt
        self.plainBody = plainBody
        self.sealedBody = sealedBody
    }
}

/// Almacenamiento de los snippets. JSON en Application Support, con los cuerpos
/// sensibles cifrados.
class SnippetStore {
    static let shared = SnippetStore()

    enum StoreError: LocalizedError {
        case emptyName
        case noTriggers
        case emptyBody
        case unreadableFile(String)

        var errorDescription: String? {
            switch self {
            case .emptyName:   return "El snippet necesita un nombre."
            case .noTriggers:  return "El snippet necesita al menos una frase que lo invoque."
            case .emptyBody:   return "El snippet necesita un texto a insertar."
            case .unreadableFile(let detail): return "No se pudo leer el archivo: \(detail)"
            }
        }
    }

    /// Formato del archivo exportado: lleva cuántos sensibles se omitieron, para
    /// que nadie crea que respaldó todo.
    struct ExportFile: Codable {
        var version: Int = 1
        var exportedAt: Date = Date()
        var omittedSensitive: Int
        var snippets: [Snippet]
    }

    private let storageURL: URL
    /// Perezoso a propósito: quien nunca marque un snippet como sensible nunca
    /// verá un diálogo del Keychain.
    private let secretBoxProvider: () throws -> SecretBox
    private var cachedBox: SecretBox?

    private(set) var snippets: [Snippet] = []

    /// `storageURL` y `secretBoxProvider` son inyectables para que los tests no
    /// toquen los snippets reales ni el Keychain del usuario.
    init(storageURL: URL? = nil, secretBoxProvider: (() throws -> SecretBox)? = nil) {
        self.storageURL = storageURL ?? SnippetStore.defaultStorageURL()
        self.secretBoxProvider = secretBoxProvider ?? { try SecretBox.keychainBacked() }
        load()
    }

    private static func defaultStorageURL() -> URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snippets.json")
    }

    private func secretBox() throws -> SecretBox {
        if let cachedBox { return cachedBox }
        let box = try secretBoxProvider()
        cachedBox = box
        return box
    }

    // MARK: - Consulta

    var activeSnippets: [Snippet] { snippets.filter { $0.isActive } }

    /// Cuerpo del snippet, descifrándolo si hace falta. Descifrar no exige
    /// autenticación: la puerta de LocalAuthentication protege *mostrar*, y de eso
    /// se encarga la UI.
    func body(of snippet: Snippet) throws -> String {
        if let plain = snippet.plainBody { return plain }
        guard let sealed = snippet.sealedBody else { return "" }
        return try secretBox().open(sealed)
    }

    /// Snippets cuyo nombre o disparadores contienen `query`, ignorando
    /// mayúsculas y acentos. Nunca busca dentro de los cuerpos: un cuerpo
    /// sensible no se filtra por el buscador.
    func search(_ query: String) -> [Snippet] {
        let needle = PhraseRewriter.normalize(query)
        guard !needle.isEmpty else { return snippets }
        return snippets.filter { snippet in
            (([snippet.name] + snippet.triggers)).contains {
                PhraseRewriter.normalize($0).contains(needle)
            }
        }
    }

    /// Otros snippets que ya usan alguno de estos disparadores.
    func snippetsClaiming(_ triggers: [String], excluding id: UUID? = nil) -> [Snippet] {
        let claimed = Set(triggers.map { PhraseRewriter.normalize($0) }.filter { !$0.isEmpty })
        return snippets.filter { snippet in
            guard snippet.id != id else { return false }
            return snippet.triggers.contains { claimed.contains(PhraseRewriter.normalize($0)) }
        }
    }

    /// Entradas del diccionario que reescriben un disparador y por tanto lo rompen.
    /// El diccionario corre antes que los snippets en el pipeline, así que el
    /// snippet nunca se activaría y sin este aviso nadie sabría por qué.
    func dictionaryCollisions(for triggers: [String],
                              entries: [DictionaryEntry]) -> [(trigger: String, entry: DictionaryEntry)] {
        var found: [(trigger: String, entry: DictionaryEntry)] = []
        for trigger in triggers where !trigger.trimmingCharacters(in: .whitespaces).isEmpty {
            for entry in entries where entry.isActive {
                let rewritten = DictionaryProcessor.apply(to: trigger, entries: [entry])
                if rewritten != trigger {
                    found.append((trigger, entry))
                }
            }
        }
        return found
    }

    /// Reglas para el motor de reescritura. `includeSensitive: false` en la
    /// ventana flotante de transcripción en vivo: flota sobre lo que el usuario
    /// esté compartiendo por pantalla.
    func rules(includeSensitive: Bool = true) -> [PhraseRewriter.Rule] {
        activeSnippets.compactMap { snippet in
            if snippet.isSensitive && !includeSensitive { return nil }
            guard let text = try? body(of: snippet), !text.isEmpty else { return nil }
            return PhraseRewriter.Rule(phrases: snippet.triggers, replacement: text)
        }
    }

    // MARK: - Mutación

    @discardableResult
    func add(name: String, triggers: [String], body: String,
             isSensitive: Bool = false, isActive: Bool = true) throws -> Snippet {
        let clean = try SnippetStore.sanitize(name: name, triggers: triggers, body: body)
        var snippet = Snippet(name: clean.name,
                              triggers: clean.triggers,
                              isSensitive: isSensitive,
                              isActive: isActive)
        try store(body: clean.body, in: &snippet, isSensitive: isSensitive)
        snippets.append(snippet)
        save()
        return snippet
    }

    /// Actualiza conservando `id` y `createdAt`.
    func update(id: UUID, name: String, triggers: [String], body: String,
                isSensitive: Bool, isActive: Bool) throws {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        let clean = try SnippetStore.sanitize(name: name, triggers: triggers, body: body)
        var snippet = snippets[index]
        snippet.name = clean.name
        snippet.triggers = clean.triggers
        snippet.isActive = isActive
        snippet.isSensitive = isSensitive
        try store(body: clean.body, in: &snippet, isSensitive: isSensitive)
        snippets[index] = snippet
        save()
    }

    func setActive(id: UUID, _ active: Bool) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[index].isActive = active
        save()
    }

    func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    private func store(body: String, in snippet: inout Snippet, isSensitive: Bool) throws {
        if isSensitive {
            snippet.sealedBody = try secretBox().seal(body)
            snippet.plainBody = nil
        } else {
            snippet.plainBody = body
            snippet.sealedBody = nil
        }
    }

    // MARK: - Importar / exportar

    /// Exporta los snippets no sensibles. Devuelve cuántos se omitieron.
    @discardableResult
    func export(to url: URL) throws -> Int {
        let exportable = snippets.filter { !$0.isSensitive }
        let omitted = snippets.count - exportable.count
        let file = ExportFile(omittedSensitive: omitted, snippets: exportable)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
        return omitted
    }

    /// Agrega los snippets del archivo. Los nombres que ya existen no se
    /// duplican. Si el archivo no es válido, lanza y nada cambia.
    @discardableResult
    func importSnippets(from url: URL) throws -> Int {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw StoreError.unreadableFile(error.localizedDescription) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Acepta el formato con metadatos y también un arreglo suelto, para no
        // pelearse con un archivo editado a mano.
        let incoming: [Snippet]
        if let file = try? decoder.decode(ExportFile.self, from: data) {
            incoming = file.snippets
        } else if let bare = try? decoder.decode([Snippet].self, from: data) {
            incoming = bare
        } else {
            throw StoreError.unreadableFile("el contenido no es un archivo de snippets de WhisperBar")
        }

        let existing = Set(snippets.map { PhraseRewriter.normalize($0.name) })
        var added = 0
        for snippet in incoming {
            guard !existing.contains(PhraseRewriter.normalize(snippet.name)) else { continue }
            // Un cuerpo cifrado importado sería ilegible: la llave no viaja.
            guard let plain = snippet.plainBody, !plain.isEmpty else { continue }
            guard let clean = try? SnippetStore.sanitize(name: snippet.name,
                                                        triggers: snippet.triggers,
                                                        body: plain) else { continue }
            snippets.append(Snippet(name: clean.name,
                                    triggers: clean.triggers,
                                    isSensitive: false,
                                    isActive: snippet.isActive,
                                    plainBody: clean.body))
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    // MARK: - Saneamiento

    static func sanitize(name: String, triggers: [String], body: String)
        throws -> (name: String, triggers: [String], body: String) {

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw StoreError.emptyName }

        var seen = Set<String>()
        var cleanTriggers: [String] = []
        for trigger in triggers {
            let trimmed = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = PhraseRewriter.normalize(trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            cleanTriggers.append(trimmed)
        }
        guard !cleanTriggers.isEmpty else { throw StoreError.noTriggers }

        // El cuerpo se recorta en los extremos pero conserva sus saltos internos:
        // una firma multilínea depende de ellos.
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { throw StoreError.emptyBody }

        return (cleanName, cleanTriggers, cleanBody)
    }

    // MARK: - Persistencia

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snippets) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        snippets = (try? decoder.decode([Snippet].self, from: data)) ?? []
    }
}
