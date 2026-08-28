import Foundation

/// Invoca whisper-cli para transcribir un archivo de audio.
class Transcriber {

    private let config = Config.shared
    private let timeout: TimeInterval = 60

    /// Margen para que los lectores de las tuberías vean EOF después de que el
    /// proceso termina o se mata. Si se agota, se devuelve lo leído hasta ahora.
    private let drainTimeout: TimeInterval = 5

    /// Protege `currentProcess` e `isCancelled`: `cancel()` corre en el hilo
    /// principal mientras `transcribe(url:)` corre en background.
    private let lock = NSLock()
    private var currentProcess: Process?
    private var isCancelled = false

    enum TranscriberError: LocalizedError {
        case invalidConfig(whisperCli: String, model: String)
        case timeout(seconds: Int)
        case cancelled
        case processFailed(status: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .invalidConfig(let cli, let model):
                return "Configuración inválida.\nwhisper-cli: \(cli)\nModelo: \(model)"
            case .timeout(let seconds):
                return "Tiempo de espera agotado (>\(seconds)s). Prueba un modelo más pequeño."
            case .cancelled:
                return "Transcripción cancelada."
            case .processFailed(let status, let stderr):
                let detail = stderr.isEmpty ? "" : "\n\(stderr)"
                return "whisper-cli falló (código \(status)).\(detail)"
            }
        }
    }

    // MARK: - Cancelación

    /// Marca la transcripción como cancelada y termina el proceso en curso si hay uno.
    /// Thread-safe: puede llamarse antes, durante o después de `transcribe(url:)`.
    func cancel() {
        lock.lock()
        isCancelled = true
        let proc = currentProcess
        currentProcess = nil
        lock.unlock()

        // Fuera del lock para no bloquear a transcribe() mientras el kernel entrega
        // la señal. `currentProcess` solo se publica tras un run() exitoso, así que
        // aquí nunca se llama terminate() sobre un proceso sin lanzar (eso lanzaría
        // NSInvalidArgumentException).
        proc?.terminate()
    }

    // MARK: - Transcripción

    /// Transcribe el archivo en `url` y devuelve el texto limpio.
    func transcribe(url: URL) -> Result<String, Error> {
        guard config.isValid else {
            return .failure(TranscriberError.invalidConfig(
                whisperCli: config.whisperCliPath,
                model:       config.modelPath
            ))
        }

        // Cada transcripción arranca limpia: cancel() pudo haberse llamado durante
        // la grabación anterior, cuando no había proceso que terminar.
        lock.lock()
        isCancelled = false
        lock.unlock()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.whisperCliPath)
        proc.arguments = [
            "-m", config.modelPath,
            "-l", config.language,
            "--no-timestamps",
            "-f", url.path,
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = errPipe

        do { try proc.run() } catch {
            return .failure(error)
        }

        // Publicar el proceso solo después de lanzarlo, para que cancel() nunca vea
        // uno sin lanzar. Si la cancelación llegó mientras se lanzaba, matarlo aquí.
        lock.lock()
        if isCancelled {
            lock.unlock()
            proc.terminate()
            return .failure(TranscriberError.cancelled)
        }
        currentProcess = proc
        lock.unlock()

        // whisper-cli escribe progreso continuo a stderr. Si nadie drena las tuberías
        // mientras corre, el búfer del kernel (~64 KB) se llena, whisper-cli queda
        // bloqueado escribiendo y la espera muere por timeout aunque el proceso esté
        // sano. Por eso se leen ambas salidas en paralelo, no después de waitUntilExit.
        let out = DataBox()
        let err = DataBox()
        let readers = DispatchGroup()
        DispatchQueue.global(qos: .utility).async(group: readers) {
            out.value = outPipe.fileHandleForReading.readDataToEndOfFile()
        }
        DispatchQueue.global(qos: .utility).async(group: readers) {
            err.value = errPipe.fileHandleForReading.readDataToEndOfFile()
        }

        let exited = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { proc.waitUntilExit(); exited.signal() }

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            _ = readers.wait(timeout: .now() + drainTimeout)
            clearCurrentProcess()
            return .failure(TranscriberError.timeout(seconds: Int(timeout)))
        }

        _ = readers.wait(timeout: .now() + drainTimeout)
        let status = proc.terminationStatus
        clearCurrentProcess()

        // terminate() desde cancel() también produce una salida "normal" con estado
        // distinto de 0; la cancelación gana para no mostrarle un error al usuario.
        lock.lock()
        let wasCancelled = isCancelled
        lock.unlock()
        if wasCancelled {
            return .failure(TranscriberError.cancelled)
        }

        let stderrText = String(data: err.value, encoding: .utf8) ?? ""
        guard status == 0 else {
            return .failure(TranscriberError.processFailed(
                status: status,
                stderr: Transcriber.lastLines(of: stderrText, count: 5)
            ))
        }

        let raw = String(data: out.value, encoding: .utf8) ?? ""
        return .success(Transcriber.cleanOutput(raw))
    }

    // MARK: - Helpers

    private func clearCurrentProcess() {
        lock.lock()
        currentProcess = nil
        lock.unlock()
    }

    /// Une los segmentos transcritos y descarta las líneas de timestamp.
    static func cleanOutput(_ raw: String) -> String {
        raw
            .components(separatedBy: .newlines)
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }   // elimina líneas de timestamp
            .joined(separator: " ")
    }

    /// Últimas `count` líneas no vacías: el stderr de whisper-cli es largo y solo
    /// el final explica el fallo.
    static func lastLines(of text: String, count: Int) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.suffix(count).joined(separator: "\n")
    }
}

/// Caja para recoger la salida de los lectores en background. La escritura ocurre
/// en la cola del lector y la lectura solo después de `DispatchGroup.wait`, que
/// hace de barrera.
private final class DataBox {
    var value = Data()
}
