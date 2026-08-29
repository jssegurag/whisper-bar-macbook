import Foundation

/// Descarga un modelo de voz desde Hugging Face.
///
/// Existe porque el botón «Descargar» de la ventana de Configuración tiene que
/// hacer el trabajo, no mandar al usuario a buscar un archivo de 3 GB con
/// instrucciones. Es la diferencia entre una app que se instala y una que se
/// explica.
///
/// Bajaba solo `large-v3`, cableado en una constante. Ahora recibe qué modelo
/// traer, porque con el modelo elegible por aplicación hace falta poder tener
/// varios descargados a la vez. Ver `VoiceModel`.
final class ModelDownloader: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case downloading(received: Int64, total: Int64)
        case finished(URL)
        case failed(String)

        /// 0…1, o nil si el servidor no informó el tamaño.
        var progress: Double? {
            guard case .downloading(let received, let total) = self, total > 0 else { return nil }
            return Double(received) / Double(total)
        }

        var isBusy: Bool {
            if case .downloading = self { return true }
            return false
        }
    }

    @Published private(set) var state: State = .idle

    /// Carpeta donde Config busca modelos por defecto.
    static var destinationDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".whisper-realtime",
                                                                      isDirectory: true)
    }

    /// Qué se está bajando ahora. Hace falta porque el destino y el tamaño ya
    /// no son constantes: dependen del modelo que pidió quien llamó.
    private var current: VoiceModel = .default
    /// Si al terminar hay que adoptar el modelo como el global.
    ///
    /// Lo decide quien llama, y no se deduce: desde Configuración el usuario está
    /// eligiendo con qué transcribe, y ahí sí; desde la pestaña de perfiles solo
    /// está trayendo un modelo para una app concreta, y cambiarle el global por
    /// eso sería decidir por él.
    private var adopts = true

    private var task: URLSessionDownloadTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    /// Tamaño legible, para el botón: «Descargar (2,9 GB)».
    static func humanSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Dónde aterriza un modelo. Se calcula a partir del modelo y no de una
    /// constante: es lo que permite tener varios descargados a la vez.
    static func destination(for model: VoiceModel) -> URL {
        destinationDirectory.appendingPathComponent(model.filename)
    }

    func start(_ model: VoiceModel = .default, adoptAsDefault: Bool = true) {
        guard !state.isBusy else { return }
        current = model
        adopts = adoptAsDefault
        try? FileManager.default.createDirectory(at: Self.destinationDirectory,
                                                withIntermediateDirectories: true)
        state = .downloading(received: 0, total: model.bytes)
        let download = session.downloadTask(with: model.url)
        task = download
        download.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
        DispatchQueue.main.async { self.state = .idle }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : current.bytes
        DispatchQueue.main.async {
            self.state = .downloading(received: totalBytesWritten, total: total)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let destination = Self.destination(for: current)
        // Se mueve dentro del callback: el archivo temporal deja de existir al
        // volver de este método.
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
            return
        }
        DispatchQueue.main.async {
            if self.adopts { Config.shared.modelPath = destination.path }
            self.state = .finished(destination)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let cancelled = (error as NSError).code == NSURLErrorCancelled
        DispatchQueue.main.async {
            self.state = cancelled ? .idle : .failed(error.localizedDescription)
        }
    }
}
