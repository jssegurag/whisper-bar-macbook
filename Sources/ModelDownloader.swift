import Foundation

/// Descarga el modelo de voz desde Hugging Face.
///
/// Existe porque el botón «Descargar» de la ventana de Configuración tiene que
/// hacer el trabajo, no mandar al usuario a buscar un archivo de 3 GB con
/// instrucciones. Es la diferencia entre una app que se instala y una que se
/// explica.
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

    /// Modelo por defecto: el mismo que documenta el README.
    static let defaultModel = (
        name: "ggml-large-v3.bin",
        bytes: Int64(3_095_033_483),
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
    )

    /// Carpeta donde Config busca modelos por defecto.
    static var destinationDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".whisper-realtime",
                                                                      isDirectory: true)
    }

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

    func start() {
        guard !state.isBusy else { return }
        try? FileManager.default.createDirectory(at: Self.destinationDirectory,
                                                withIntermediateDirectories: true)
        state = .downloading(received: 0, total: Self.defaultModel.bytes)
        let download = session.downloadTask(with: Self.defaultModel.url)
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
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : Self.defaultModel.bytes
        DispatchQueue.main.async {
            self.state = .downloading(received: totalBytesWritten, total: total)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let destination = Self.destinationDirectory
            .appendingPathComponent(Self.defaultModel.name)
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
            Config.shared.modelPath = destination.path
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
