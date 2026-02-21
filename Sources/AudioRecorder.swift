import AVFoundation

/// Graba audio del micrófono en formato PCM 16kHz mono (requerido por Whisper).
class AudioRecorder {

    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    private(set) var isRecording = false

    /// Archivo temporal donde se guarda la grabación
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_recording.wav")

    // MARK: - Ciclo de grabación

    /// Inicia la grabación. Lanza error si el micrófono no está disponible.
    func start() throws {
        guard !isRecording else { return }
        let settings: [String: Any] = [
            AVFormatIDKey:             Int(kAudioFormatLinearPCM),
            AVSampleRateKey:           16_000.0,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder?.record()
        isRecording = true
        startTime   = Date()
    }

    /// Detiene la grabación y devuelve la duración en segundos.
    @discardableResult
    func stop() -> TimeInterval {
        recorder?.stop()
        isRecording = false
        let duration = Date().timeIntervalSince(startTime ?? Date())
        startTime = nil   // limpiar para que no reutilice el tiempo de grabaciones anteriores
        return duration
    }

    // MARK: - Permisos

    /// Solicita acceso al micrófono. Debe llamarse al iniciar la app.
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}
