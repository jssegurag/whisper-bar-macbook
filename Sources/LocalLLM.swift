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
            case .noModel:
                return "La ruta del modelo no apunta a un .gguf válido. El modelo de "
                     + "voz (ggml-….bin) no sirve aquí: hace falta un .gguf en "
                     + "~/.whisper-realtime/"
            case .noServer:
                return "La ruta de llama-server no apunta a un ejecutable. "
                     + "Instálalo con: brew install llama.cpp"
            }
        }
    }

    /// Por qué falló una petición. Existe porque la primera versión devolvía `nil`
    /// para todo, y un fallo real —una carpeta elegida como si fuera el binario—
    /// llegaba al usuario como «no respondió», que no dice qué arreglar.
    enum AskError: Error, Equatable {
        case unavailable(Availability)
        case noPort
        case cannotLaunch(String)
        case serverDied
        case neverHealthy
        case noResponse
        case badResponse

        var message: String {
            switch self {
            case .unavailable(let a): return a.message
            case .noPort:
                return "El sistema no dio un puerto libre."
            case .cannotLaunch(let d):
                return "No se pudo ejecutar llama-server: \(d)"
            case .serverDied:
                return "llama-server se cerró al arrancar. Suele ser el .gguf "
                     + "corrupto o a medio descargar, o RAM insuficiente."
            case .neverHealthy:
                return "llama-server arrancó pero no terminó de cargar el modelo "
                     + "a tiempo."
            case .noResponse:
                return "El servidor no contestó a tiempo."
            case .badResponse:
                return "El servidor contestó algo que no se pudo interpretar."
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
        if case .success(let t) = askReporting(system: system, user: user,
                                               maxTokens: maxTokens,
                                               temperature: temperature) { return t }
        return nil
    }

    /// Igual que `ask`, pero dice por qué falló. La UI usa esta.
    static func askReporting(system: String,
                             user: String,
                             maxTokens: Int = 512,
                             temperature: Double = 0.2) -> Result<String, AskError> {
        let estado = availability
        guard estado.isAvailable else { return .failure(.unavailable(estado)) }
        let puerto: Int
        switch ensureRunningReporting() {
        case .success(let p): puerto = p
        case .failure(let e): return .failure(e)
        }

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
        else { return .failure(.badResponse) }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = datos
        req.timeoutInterval = requestTimeout

        guard let respuesta = sincrono(req) else { return .failure(.noResponse) }
        guard let json = try? JSONSerialization.jsonObject(with: respuesta) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let texto = message["content"] as? String
        else { return .failure(.badResponse) }

        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpio.isEmpty ? .failure(.badResponse) : .success(limpio)
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
        if case .success(let p) = ensureRunningReporting() { return p }
        return nil
    }

    private static func ensureRunningReporting() -> Result<Int, AskError> {
        lock.lock()
        if let p = process, p.isRunning, port > 0 {
            let actual = port
            lock.unlock()
            return .success(actual)
        }
        // Un proceso muerto que quedó guardado engañaría al siguiente que pregunte.
        process = nil
        port = 0
        lock.unlock()

        guard let puerto = freePort() else { return .failure(.noPort) }
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

        do { try p.run() } catch {
            return .failure(.cannotLaunch(error.localizedDescription))
        }

        if !waitUntilHealthy(port: puerto, process: p) {
            let murio = !p.isRunning
            if p.isRunning { p.terminate() }
            return .failure(murio ? .serverDied : .neverHealthy)
        }

        lock.lock()
        process = p
        port = puerto
        lock.unlock()
        return .success(puerto)
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
