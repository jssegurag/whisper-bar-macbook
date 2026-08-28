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
        // La onda de la píldora sigue el volumen real de la voz. Sin esto sería
        // una animación decorativa que se movería igual en silencio.
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        startTime   = Date()
    }

    /// Nivel de voz actual, 0…1, para modular la onda de la píldora.
    ///
    /// El mapeo lleva −50 dB a 0 y −5 dB a 1: por debajo es silencio de sala, por
    /// encima ya está saturando.
    func currentLevel() -> CGFloat {
        guard let recorder, isRecording else { return 0 }
        recorder.updateMeters()
        let dB = recorder.averagePower(forChannel: 0)
        let normalized = (Double(dB) + 50) / 45
        return CGFloat(min(max(normalized, 0), 1))
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
