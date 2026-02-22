import Foundation

/// Gestiona un proceso whisper-stream para transcripción en tiempo real.
/// Lee stdout progresivamente y notifica via callback con texto actualizado.
class StreamingTranscriber {

    private let config = Config.shared
    private var process: Process?
    private var outputPipe: Pipe?
    private(set) var isRunning = false

    /// Callback invocado en main thread con cada fragmento de texto nuevo.
    var onTextUpdate: ((String) -> Void)?

    // MARK: - Validación

    var isValid: Bool {
        FileManager.default.isExecutableFile(atPath: config.whisperStreamPath)
            && config.isModelValid
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning, isValid else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.whisperStreamPath)
        proc.arguments = [
            "-m", config.modelPath,
            "-l", config.language,
            "--step", String(config.streamStepMs),
            "--length", String(config.streamLengthMs),
            "--keep", String(config.streamKeepMs),
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        proc.standardInput  = FileHandle.nullDevice

        // Leer stdout asincrónicamente
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                let cleaned = self?.cleanStreamOutput(text) ?? text
                if !cleaned.isEmpty {
                    DispatchQueue.main.async {
                        self?.onTextUpdate?(cleaned)
                    }
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.outputPipe = pipe
            self.isRunning = true
        } catch {
            // Fallo silencioso — el panel mostrará que no está activo
        }
    }

    func stop() {
        guard isRunning else { return }
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
    }

    // MARK: - Limpieza de output

    /// Limpia el output de whisper-stream (elimina timestamps, líneas vacías).
    private func cleanStreamOutput(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
            .joined(separator: " ")
    }
}
