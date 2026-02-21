import AVFoundation

/// Genera un acorde relajante con binaural beat de 4 Hz (theta) durante la transcripción.
/// - Canal izquierdo : 256 Hz + 440 Hz
/// - Canal derecho   : 256 Hz + 444 Hz  → beat percibido: 4 Hz (relajación profunda)
/// - Modulación de amplitud a 4 Hz para efecto "respiración"
/// Funciona con altavoces; mejor aún con auriculares.
class AudioFeedback {

    private let engine    = AVAudioEngine()
    private let player    = AVAudioPlayerNode()
    private let mixer     = AVAudioMixerNode()
    private let sampleRate: Double = 44100
    private let amplitude:  Float  = 0.07
    private(set) var isPlaying = false

    private var fadeTimer: Timer?

    // MARK: - Público

    func start() {
        guard !isPlaying else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(player)
        engine.attach(mixer)
        engine.connect(player, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        mixer.outputVolume = 0
        do { try engine.start() } catch { return }
        player.scheduleBuffer(makeBuffer(), at: nil, options: .loops)
        player.play()
        isPlaying = true
        fadeVolume(to: amplitude * 1.0, duration: 1.2)   // fade-in suave
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        fadeVolume(to: 0, duration: 0.6) { [weak self] in
            self?.player.stop()
            self?.engine.stop()
            self?.engine.detach(self!.player)
            self?.engine.detach(self!.mixer)
        }
    }

    // MARK: - Privado

    private func fadeVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let steps   = 30
        let interval = duration / Double(steps)
        let start   = mixer.outputVolume
        var step    = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let t = Float(step) / Float(steps)
            self.mixer.outputVolume = start + (target - start) * t
            if step >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }

    private func makeBuffer() -> AVAudioPCMBuffer {
        let frameCount: AVAudioFrameCount = 44100    // 1 s, se repite en loop
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer  = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let left  = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        let pi2   = 2.0 * Double.pi

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Modulación de respiración (4 Hz, amplitud 0.12)
            let breathe = Float(sin(pi2 * 4 * t) * 0.12 + 0.88)
            // Acorde: fundamental 256 Hz (C4) + carrier 440/444 Hz (A4)
            let c4  = Float(sin(pi2 * 256 * t))
            let a4L = Float(sin(pi2 * 440 * t))
            let a4R = Float(sin(pi2 * 444 * t))   // 4 Hz por debajo → beat theta
            left[i]  = (c4 * 0.35 + a4L * 0.65) * breathe
            right[i] = (c4 * 0.35 + a4R * 0.65) * breathe
        }
        return buffer
    }
}
