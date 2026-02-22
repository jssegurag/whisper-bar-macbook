import Foundation

/// Una entrada del historial de transcripciones.
struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let text: String
    let duration: TimeInterval
    let sourceApp: String?

    init(text: String, duration: TimeInterval, sourceApp: String? = nil) {
        self.id        = UUID()
        self.timestamp = Date()
        self.text      = text
        self.duration  = duration
        self.sourceApp = sourceApp
    }
}

/// Gestiona el almacenamiento persistente del historial de transcripciones.
class TranscriptionHistory {
    static let shared = TranscriptionHistory()

    private let config = Config.shared
    private var entries: [TranscriptionEntry] = []

    private var storageURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    init() { load() }

    // MARK: - API pública

    var allEntries: [TranscriptionEntry] { entries }

    func add(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0)
        let max = config.maxHistoryCount
        if entries.count > max {
            entries = Array(entries.prefix(max))
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistencia

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([TranscriptionEntry].self, from: data)) ?? []
    }
}
