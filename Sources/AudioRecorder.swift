import AVFoundation

/// Graba audio del micrófono en formato PCM 16kHz mono (requerido por Whisper).
class AudioRecorder {

    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    private(set) var isRecording = false

    /// Archivo temporal donde se guarda la grabación
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_recording.wav")

    /// Formato exigido por Whisper: PCM lineal, 16 kHz, mono, 16 bits.
    static let recordSettings: [String: Any] = [
        AVFormatIDKey:             Int(kAudioFormatLinearPCM),
        AVSampleRateKey:           16_000.0,
        AVNumberOfChannelsKey:     1,
        AVLinearPCMBitDepthKey:    16,
        AVLinearPCMIsFloatKey:     false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    enum AudioRecorderError: LocalizedError {
        case couldNotStart

        var errorDescription: String? {
            switch self {
            case .couldNotStart:
                return "No se pudo iniciar la grabación. Revisa el permiso de Micrófono "
                     + "en Ajustes del Sistema → Privacidad y seguridad, y que ninguna "
                     + "otra app tenga el micrófono ocupado."
            }
        }
    }

    // MARK: - Ciclo de grabación

    /// Inicia la grabación. Lanza error si el micrófono no está disponible.
    func start() throws {
        guard !isRecording else { return }
        let rec = try AVAudioRecorder(url: outputURL, settings: AudioRecorder.recordSettings)
        // La onda de la píldora sigue el volumen real de la voz. Sin esto sería
        // una animación decorativa que se movería igual en silencio.
        rec.isMeteringEnabled = true

        // record() devuelve false si el permiso está denegado o el micrófono está
        // ocupado. Descartar ese Bool dejaba la app en estado "grabando": el icono
        // animaba, el usuario dictaba y whisper-cli recibía un WAV vacío, así que la
        // transcripción llegaba en blanco sin ningún error visible.
        guard rec.record() else {
            recorder = nil
            throw AudioRecorderError.couldNotStart
        }

        recorder    = rec
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
        // El pico manda sobre el promedio: el promedio de una ventana de voz
        // normal se queda en la mitad baja de la escala y la onda apenas se movía.
        // Se atenúa 6 dB para que un golpe seco no sature la barra entera.
        let average = Double(recorder.averagePower(forChannel: 0))
        let peak = Double(recorder.peakPower(forChannel: 0))
        let dB = max(average, peak - 6)
        // −45 dB es silencio de sala, −5 dB ya está saturando.
        let normalized = (dB + 45) / 40
        return CGFloat(min(max(normalized, 0), 1))
    }

    /// Detiene la grabación y devuelve la duración en segundos.
    @discardableResult
    func stop() -> TimeInterval {
        recorder?.stop()
        recorder = nil
        isRecording = false
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        startTime = nil   // limpiar para que no reutilice el tiempo de grabaciones anteriores
        return duration
    }

    // MARK: - Permisos

    /// Solicita acceso al micrófono. Debe llamarse al iniciar la app.
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}
