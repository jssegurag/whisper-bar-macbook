import Foundation

/// ViewModel para el overlay de transcripción flotante en tiempo real.
class FloatingTranscriptionViewModel: ObservableObject {
    @Published var displayText: String = ""
    @Published var isActive: Bool = false

    private let streamer = StreamingTranscriber()
    var onClose: (() -> Void)?

    /// Máximo de caracteres en el buffer de display (rolling).
    private let maxDisplayLength = 800

    init() {
        streamer.onTextUpdate = { [weak self] text in
            guard let self else { return }
            self.appendText(text)
        }
    }

    func toggle() {
        if isActive { stop() } else { start() }
    }

    func start() {
        guard !isActive else { return }
        displayText = ""
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
    }

    private func appendText(_ text: String) {
        displayText += text
        // Buffer rolling: mantener solo los últimos N caracteres
        if displayText.count > maxDisplayLength {
            let startIndex = displayText.index(
                displayText.endIndex, offsetBy: -maxDisplayLength)
            displayText = String(displayText[startIndex...])
        }
    }
}
