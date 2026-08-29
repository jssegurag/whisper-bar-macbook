import Foundation

/// Los perfiles y su archivo, siguiendo el patrón de `dictionary.json` y
/// `snippets.json`: mismo directorio, misma escritura atómica, mismo `storageURL`
/// inyectable para que las pruebas no toquen los datos del usuario.
///
/// A diferencia de aquellos dos, el archivo lleva un sobre con `version`. Los
/// otros nacieron sin él y ya no se les puede añadir sin migrar; aquí sale gratis
/// y evita ese mismo problema dentro de un año.
final class ProfileStore: ObservableObject {

    static let shared = ProfileStore()

    /// Versión del formato en disco. Sube cuando la forma del archivo cambie de
    /// una manera que esta versión no sepa leer.
    static let currentVersion = 1

    /// El sobre. Existe para que `version` viva junto a los datos y no en un
    /// archivo aparte que se puede desincronizar.
    private struct Envelope: Codable {
        var version: Int
        var profiles: [Profile]
    }

    @Published private(set) var profiles: [Profile] = []

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        load()
    }

    private static func defaultStorageURL() -> URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            // "WhisperBar" y no "Gluffi" a propósito: es la carpeta que ya tiene
            // los datos del usuario. Ver CLAUDE.md.
            .appendingPathComponent("WhisperBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }

    // MARK: - Lectura

    /// Los que participan en la resolución, en orden de prioridad.
    var activeProfiles: [Profile] { profiles.filter(\.isActive) }

    func profile(with id: UUID) -> Profile? { profiles.first { $0.id == id } }

    // MARK: - Escritura

    func add(_ profile: Profile) {
        profiles.append(profile)
        sortAndSave()
    }

    func update(_ profile: Profile) {
        guard let i = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[i] = profile
        sortAndSave()
    }

    func remove(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        renumber()
        save()
    }

    /// Reordenar por arrastre. Renumera después: si el orden dependiera de los
    /// valores previos, arrastrar dos veces dejaría huecos y empates.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        renumber()
        save()
    }

    /// Sustituye la lista entera. Para la siembra inicial.
    func replaceAll(with nuevos: [Profile]) {
        profiles = nuevos
        renumber()
        save()
    }

    // MARK: - Persistencia

    /// Ordena y guarda, **sin renumerar**. Renumerar aquí pisaría el `order` que
    /// pide quien da de alta: dar de alta tres perfiles con órdenes 2, 0 y 1 los
    /// dejaba en el orden de llegada, porque cada alta aplanaba el anterior a 0.
    /// La numeración solo se rehace cuando las posiciones cambian de verdad.
    private func sortAndSave() {
        profiles.sort(by: Self.before)
        save()
    }

    /// Orden que usa toda la clase. Desempata por id, no por posición de
    /// llegada: dos perfiles con el mismo `order` —posible si alguien edita el
    /// JSON a mano— tienen que resolverse igual en cada arranque, o el perfil
    /// que gana cambiaría solo.
    private static func before(_ a: Profile, _ b: Profile) -> Bool {
        a.order != b.order ? a.order < b.order : a.id.uuidString < b.id.uuidString
    }

    private func renumber() {
        for i in profiles.indices { profiles[i].order = i }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(
            Envelope(version: Self.currentVersion, profiles: profiles)) else { return }
        // `.atomic` escribe a un temporal y renombra, así que un cierre a medias
        // deja el archivo anterior intacto en vez de uno truncado.
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            // Un archivo ilegible deja la lista vacía y **no se borra**:
            // sobrescribirlo a ciegas convertiría un problema recuperable a mano
            // en una pérdida definitiva.
            return
        }
        profiles = envelope.profiles.sorted(by: Self.before)
    }
}
