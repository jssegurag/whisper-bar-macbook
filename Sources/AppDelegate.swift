import Cocoa
import CoreGraphics

/// Coordina todos los módulos y gestiona la barra de menú.
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Dependencias

    private let config        = Config.shared
    private let recorder      = AudioRecorder()
    private let transcriber   = Transcriber()
    private let hotkey        = HotkeyManager()
    private let audioFeedback = AudioFeedback()
    private let llmProcessor  = LLMProcessor()

    private var statusItem: NSStatusItem!

    // MARK: - Animación de grabación

    private var animTimer: Timer?
    private var animPhase: CGFloat = 0

    // MARK: - Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        AudioRecorder.requestPermission { _ in }

        hotkey.onKeyDown = { [weak self] in self?.startRecording() }
        hotkey.onKeyUp   = { [weak self] in self?.stopAndTranscribe() }
        hotkey.setupWhenReady()

        if !config.isValid {
            notify("⚠️ Configuración incompleta — abre el menú para ver el estado")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.tearDown()
        stopRecordingAnimation()
    }

    // MARK: - Barra de menú

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIconEmoji("🎙")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "WhisperBar", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Mantén ⌘⌥ para grabar", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        menu.addItem(statusMenuItem(for: config.isWhisperCliValid,
                                    ok:  "whisper-cli: \(URL(fileURLWithPath: config.whisperCliPath).lastPathComponent)",
                                    err: "❌ whisper-cli no encontrado"))
        menu.addItem(statusMenuItem(for: config.isModelValid,
                                    ok:  "Modelo: \(URL(fileURLWithPath: config.modelPath).lastPathComponent)",
                                    err: "❌ Modelo no encontrado"))

        if config.llmEnabled {
            menu.addItem(statusMenuItem(for: config.isLlmCliValid,
                                        ok:  "LLM: \(URL(fileURLWithPath: config.llmCliPath).lastPathComponent)",
                                        err: "❌ llama-cli no encontrado"))
            menu.addItem(statusMenuItem(for: config.isLlmModelValid,
                                        ok:  "LLM Modelo: \(URL(fileURLWithPath: config.llmModelPath).lastPathComponent)",
                                        err: "❌ LLM Modelo no configurado"))
        } else {
            let llmOff = NSMenuItem(title: "LLM: desactivado", action: nil, keyEquivalent: "")
            llmOff.isEnabled = false
            menu.addItem(llmOff)
        }

        let langItem = NSMenuItem(title: "Idioma: \(config.language)", action: nil, keyEquivalent: "")
        langItem.isEnabled = false
        menu.addItem(langItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferencias…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(withTitle: "Salir", action: #selector(quit), keyEquivalent: "q")

        statusItem.menu = menu
    }

    private func statusMenuItem(for ok: Bool, ok okText: String, err errText: String) -> NSMenuItem {
        let item = NSMenuItem(title: ok ? "✅ \(okText)" : errText, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Iconos

    /// Icono de emoji estático (idle / procesando)
    private func setIconEmoji(_ s: String) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = nil
            self.statusItem.button?.title = s
        }
    }

    /// Imagen dinámica para la animación de grabación
    private func makeWaveformImage(phase: CGFloat) -> NSImage {
        let w: CGFloat = 28
        let h: CGFloat = 18
        return NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            let nBars   = 4
            let barW:  CGFloat = 3.5
            let gap:   CGFloat = 2.5
            let total  = CGFloat(nBars) * barW + CGFloat(nBars - 1) * gap
            let startX = (w - total) / 2
            let phases: [CGFloat] = [0, 1.1, 2.0, 3.0]   // desfase por barra

            NSColor.systemRed.withAlphaComponent(0.92).setFill()
            for i in 0..<nBars {
                let barHeight = (sin(phase + phases[i]) * 0.42 + 0.58) * (h - 4)
                let x = startX + CGFloat(i) * (barW + gap)
                let y = (h - barHeight) / 2
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: y, width: barW, height: barHeight),
                    xRadius: barW / 2, yRadius: barW / 2
                ).fill()
            }
            return true
        }
    }

    // MARK: - Animación de grabación

    private func startRecordingAnimation() {
        animPhase = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animPhase += 0.28
            let img = self.makeWaveformImage(phase: self.animPhase)
            self.statusItem.button?.image = img
            self.statusItem.button?.title = ""
        }
    }

    private func stopRecordingAnimation() {
        animTimer?.invalidate()
        animTimer = nil
    }

    // MARK: - Grabación

    private func startRecording() {
        do {
            try recorder.start()
            startRecordingAnimation()
        } catch {
            notify("Error al iniciar grabación: \(error.localizedDescription)")
        }
    }

    private func stopAndTranscribe() {
        guard recorder.isRecording else { return }
        stopRecordingAnimation()

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            setIconEmoji("🎙")
            return
        }

        setIconEmoji("⏳")
        audioFeedback.start()

        let audioURL = recorder.outputURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            switch self.transcriber.transcribe(url: audioURL) {
            case .success(let text) where !text.isEmpty:
                // LLM post-procesamiento (retorna texto original si está deshabilitado)
                self.setIconEmoji("🧠")
                let finalText: String
                switch self.llmProcessor.process(text: text) {
                case .success(let processed):
                    finalText = processed
                case .failure(let llmError):
                    self.notify("LLM error (usando texto original): \(llmError.localizedDescription)")
                    finalText = text
                }
                DispatchQueue.main.async { self.audioFeedback.stop() }
                self.paste(text: finalText)
            case .failure(let error):
                DispatchQueue.main.async { self.audioFeedback.stop() }
                self.notify("Error: \(error.localizedDescription)")
                self.setIconEmoji("🎙")
            default:
                DispatchQueue.main.async { self.audioFeedback.stop() }
                self.setIconEmoji("🎙")
            }
        }
    }

    // MARK: - Paste (preserva el clipboard del usuario)

    private func paste(text: String) {
        let previous = NSPasteboard.general.string(forType: .string)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let src  = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if let previous {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
            self?.setIconEmoji("🎙")
            self?.rebuildMenu()
        }
    }

    // MARK: - Notificaciones

    private func notify(_ msg: String) {
        let escaped = msg.replacingOccurrences(of: "\"", with: "\\\"")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", "display notification \"\(escaped)\" with title \"WhisperBar\""]
        proc.standardOutput = Pipe()
        proc.standardError  = Pipe()
        try? proc.run()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
