import Foundation

/// Motor del modelo de lenguaje local.
///
/// Habla con `llama-server` por HTTP en vez de invocar `llama-cli` por llamada, y
/// la razón está medida en este proyecto: una llamada suelta tarda ~25 s porque
/// recarga los 2,5 GB del modelo cada vez, contra ~1,5 s con el modelo residente.
///
/// El precio de tenerlo residente son ~3 GB de RAM, así que el servidor se
/// arranca al primer uso y se apaga solo tras unos minutos sin trabajo. Nadie
/// paga por un modelo que no está usando.
///
/// Cualquier fallo devuelve `nil`. Quien llama decide qué hacer sin ese resultado,
/// y en esta app la respuesta siempre es seguir con el texto original.
enum LocalLLM {

    enum Availability: Equatable {
        case available
        case noModel
        case noServer

        var isAvailable: Bool { self == .available }

        var message: String {
            switch self {
            case .available: return "Listo."
            case .noModel:   return "Falta el modelo .gguf. Descárgalo a ~/.whisper-realtime/"
            case .noServer:  return "Falta llama-server. Instálalo con: brew install llama.cpp"
            }
        }
    }

    static var availability: Availability {
        let config = Config.shared
        if !config.isLlamaServerValid { return .noServer }
        if !config.isLlmModelValid { return .noModel }
        return .available
    }

    // MARK: - Estado del servidor

    private static let lock = NSLock()
    private static var process: Process?
    private static var port: Int = 0
    private static var idleTimer: DispatchSourceTimer?

    /// Cuánto se espera a que el modelo cargue. Un GGUF de varios GB desde disco
    /// frío tarda; quedarse corto aquí se ve como «el modelo no funciona».
    static let startupTimeout: TimeInterval = 90

    /// Techo por petición. Corta el caso en que el modelo se pone a divagar.
    static let requestTimeout: TimeInterval = 30

    static var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return process?.isRunning == true
    }

    // MARK: - API

    /// Pregunta al modelo. Bloquea, así que va en una cola de fondo.
    /// Devuelve `nil` ante cualquier fallo: servidor caído, timeout, JSON raro.
    static func ask(system: String,
                    user: String,
                    maxTokens: Int = 512,
                    temperature: Double = 0.2) -> String? {
        guard availability.isAvailable else { return nil }
        guard let puerto = ensureRunning() else { return nil }

        defer { scheduleIdleShutdown() }

        let cuerpo: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        guard let datos = try? JSONSerialization.data(withJSONObject: cuerpo),
              let url = URL(string: "http://127.0.0.1:\(puerto)/v1/chat/completions")
        else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = datos
        req.timeoutInterval = requestTimeout

        guard let respuesta = sincrono(req) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: respuesta) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let texto = message["content"] as? String
        else { return nil }

        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpio.isEmpty ? nil : limpio
    }

    /// Apaga el servidor y libera la RAM. Idempotente.
    static func shutdown() {
        lock.lock()
        idleTimer?.cancel()
        idleTimer = nil
        let p = process
        process = nil
        port = 0
        lock.unlock()

        guard let p, p.isRunning else { return }
        p.terminate()
        // Si no se va por las buenas en un segundo, se va por las malas: dejar
        // 3 GB de RAM colgando es peor que un SIGKILL.
        let plazo = Date().addingTimeInterval(1)
        while p.isRunning && Date() < plazo { usleep(50_000) }
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
    }

    // MARK: - Ciclo de vida

    /// Devuelve el puerto de un servidor vivo, arrancándolo si hace falta.
    private static func ensureRunning() -> Int? {
        lock.lock()
        if let p = process, p.isRunning, port > 0 {
            let actual = port
            lock.unlock()
            return actual
        }
        // Un proceso muerto que quedó guardado engañaría al siguiente que pregunte.
        process = nil
        port = 0
        lock.unlock()

        guard let puerto = freePort() else { return nil }
        let config = Config.shared

        let p = Process()
        p.executableURL = URL(fileURLWithPath: config.llamaServerPath)
        p.arguments = [
            "-m", config.llmModelPath,
            "--port", String(puerto),
            "--ctx-size", String(config.llmContextSize),
            "-ngl", "99",              // todas las capas a la GPU
            "--host", "127.0.0.1",     // solo local: esto no se expone a la red
        ]
        // Sin drenar, las tuberías se llenan y el proceso se bloquea al escribir.
        // Es el mismo fallo que ya nos costó un timeout falso en Transcriber.
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice

        do { try p.run() } catch { return nil }

        guard waitUntilHealthy(port: puerto, process: p) else {
            if p.isRunning { p.terminate() }
            return nil
        }

        lock.lock()
        process = p
        port = puerto
        lock.unlock()
        return puerto
    }

    private static func waitUntilHealthy(port: Int, process p: Process) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        let limite = Date().addingTimeInterval(startupTimeout)
        while Date() < limite {
            // Si el servidor se murió al arrancar (modelo corrupto, RAM
            // insuficiente), esperar los 90 s completos no aporta nada.
            guard p.isRunning else { return false }
            var req = URLRequest(url: url)
            req.timeoutInterval = 2
            if let d = sincrono(req),
               let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               (json["status"] as? String) == "ok" {
                return true
            }
            usleep(300_000)
        }
        return false
    }

    private static func scheduleIdleShutdown() {
        let minutos = Config.shared.llmIdleMinutes
        lock.lock()
        idleTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        t.schedule(deadline: .now() + .seconds(minutos * 60))
        t.setEventHandler { shutdown() }
        idleTimer = t
        lock.unlock()
        t.resume()
    }

    // MARK: - Utilidades

    /// Pide al sistema un puerto libre. Elegir uno fijo choca con otra copia de
    /// la app, o con un llama-server que el usuario tenga abierto por su cuenta.
    static func freePort() -> Int? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0                        // 0 = que el kernel elija
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        let ok = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard ok else { return nil }

        var asignada = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let leido = withUnsafeMutablePointer(to: &asignada) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len) == 0
            }
        }
        guard leido else { return nil }
        return Int(UInt16(bigEndian: asignada.sin_port))
    }

    /// URLSession en modo bloqueante. La app ya llama a whisper así, desde una
    /// cola de fondo; mantener el mismo modelo evita mezclar dos estilos.
    private static func sincrono(_ req: URLRequest) -> Data? {
        let sem = DispatchSemaphore(value: 0)
        var salida: Data?
        URLSession.shared.dataTask(with: req) { d, _, _ in
            salida = d
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + req.timeoutInterval + 5)
        return salida
    }
}
