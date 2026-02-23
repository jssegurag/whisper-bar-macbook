import Foundation

/// ViewModel para el overlay de transcripción flotante en tiempo real.
/// Separa texto finalizado (confirmado) de texto parcial (en progreso).
class FloatingTranscriptionViewModel: ObservableObject {
    @Published var displayText: String = ""
    @Published var isActive: Bool = false

    private let streamer = StreamingTranscriber()
    var onClose: (() -> Void)?

    /// Máximo de caracteres en el buffer de texto finalizado (rolling).
    private let maxDisplayLength = 800

    /// Último fragmento finalizado recibido (para deduplicación anti-loop).
    var lastFragment: String = ""
    /// Contador de repeticiones consecutivas del mismo fragmento.
    var repeatCount: Int = 0
    /// Máximo de repeticiones antes de silenciar (anti-hallucination loop).
    let maxRepeats: Int = 2

    /// Texto confirmado acumulado (líneas finalizadas por whisper-stream).
    var finalizedText: String = ""

    init() {
        streamer.onFinalizedText = { [weak self] text in
            guard let self else { return }
            self.appendFinalizedText(text)
        }
        streamer.onPartialUpdate = { [weak self] text in
            guard let self else { return }
            self.updatePartial(text)
        }
    }

    func toggle() {
        if isActive { stop() } else { start() }
    }

    func start() {
        guard !isActive else { return }
        displayText = ""
        finalizedText = ""
        lastFragment = ""
        repeatCount = 0
        streamer.start()
        isActive = streamer.isRunning
    }

    func stop() {
        guard isActive else { return }
        streamer.stop()
        isActive = false
    }

    func close() {
        stop()
        onClose?()
    }

    func clear() {
        displayText = ""
        finalizedText = ""
        lastFragment = ""
        repeatCount = 0
    }

    /// Agrega texto confirmado/finalizado al transcript permanente.
    func appendFinalizedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Deduplicación: detectar loops de texto repetitivo (anti-alucinación)
        if trimmed == lastFragment {
            repeatCount += 1
            if repeatCount >= maxRepeats {
                return  // Silenciar repeticiones (probable alucinación)
            }
        } else {
            lastFragment = trimmed
            repeatCount = 0
        }

        if finalizedText.isEmpty {
            finalizedText = trimmed
        } else {
            finalizedText += " " + trimmed
        }

        // Buffer rolling: mantener solo los últimos N caracteres
        if finalizedText.count > maxDisplayLength {
            let startIndex = finalizedText.index(
                finalizedText.endIndex, offsetBy: -maxDisplayLength)
            finalizedText = String(finalizedText[startIndex...])
        }

        displayText = finalizedText
    }

    /// Actualiza el texto parcial (en progreso) mostrado después del texto finalizado.
    /// Este texto se reemplaza con cada actualización — no se acumula.
    func updatePartial(_ text: String) {
        if text.isEmpty {
            displayText = finalizedText
        } else {
            displayText = finalizedText.isEmpty ? text : finalizedText + " " + text
        }
    }
}
