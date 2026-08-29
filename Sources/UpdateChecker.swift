import Foundation

/// Verifica y aplica actualizaciones de Homebrew para whisper-cpp.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum PackageState: Equatable {
        case idle                  // sin verificación iniciada
        case checking              // corriendo brew outdated
        case upToDate              // sin actualizaciones
        case available(String)     // nueva versión disponible
        case upgrading             // corriendo brew upgrade
        case upgraded              // upgrade completado exitosamente
        case error(String)         // error al verificar o actualizar
    }

    @Published var whisperState: PackageState = .idle

    private var isChecking = false
    private var lastCheckDate: Date? = nil
    private let checkInterval: TimeInterval = 3600  // re-verifica como mínimo cada 1h

    private let brewPath: String

    private init() {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        brewPath = candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? "/opt/homebrew/bin/brew"
    }

    // MARK: - API pública

    /// Verifica actualizaciones. Omite si se verificó recientemente (salvo force: true).
    func checkForUpdates(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if !force, let last = lastCheckDate,
           Date().timeIntervalSince(last) < checkInterval {
            completion?(hasAnyUpdate)
            return
        }
        guard !isChecking else { completion?(hasAnyUpdate); return }
        isChecking = true
        whisperState = .checking

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let whisperNew = self.runOutdatedCheck()
            DispatchQueue.main.async {
                self.isChecking = false
                self.lastCheckDate = Date()
                self.whisperState = whisperNew.map { .available($0) } ?? .upToDate
                completion?(self.hasAnyUpdate)
            }
        }
    }

    func upgradeWhisper() {
        runUpgrade(package: "whisper-cpp") { [weak self] success in
            self?.whisperState = success ? .upgraded : .error("Falló la actualización")
        }
    }


    /// True si al menos un paquete tiene actualización disponible.
    var hasAnyUpdate: Bool {
        if case .available = whisperState { return true }
        return false
    }

    // MARK: - Privado

    /// Instala un paquete con Homebrew. Lo usa la ventana de Configuración para
    /// resolver «whisper-stream no está instalado» sin mandar al usuario a la
    /// terminal.
    func install(package: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-lc", "brew install \(package) 2>&1 | tail -5"]
            proc.environment = self.brewEnvironment()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do { try proc.run() } catch {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            let ok = proc.terminationStatus == 0
            DispatchQueue.main.async { completion(ok, output) }
        }
    }

    private func runOutdatedCheck() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: brewPath)
        proc.arguments = ["outdated", "--verbose", "whisper-cpp"]
        proc.environment = brewEnvironment()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
        var whisper: String? = nil

        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            if line.lowercased().contains("whisper-cpp") {
                whisper = parseNewVersion(from: line)
            }
        }
        return whisper
    }

    /// "whisper-cpp (1.8.4) < 1.8.5" → "1.8.5"
    private func parseNewVersion(from line: String) -> String {
        if let range = line.range(of: "< ") {
            let v = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? "nueva versión" : v
        }
        return "nueva versión"
    }

    private func runUpgrade(package: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.whisperState = .upgrading
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: self.brewPath)
            proc.arguments = ["upgrade", package]
            proc.environment = self.brewEnvironment()
            proc.standardOutput = Pipe()
            proc.standardError  = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let success = proc.terminationStatus == 0
            DispatchQueue.main.async { completion(success) }
        }
    }

    private func brewEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"   // evita que brew actualice su propia DB
        env["HOMEBREW_NO_ENV_HINTS"]   = "1"
        let brewBin = URL(fileURLWithPath: brewPath).deletingLastPathComponent().path
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        env["PATH"] = "\(brewBin):\(currentPath)"
        return env
    }
}
