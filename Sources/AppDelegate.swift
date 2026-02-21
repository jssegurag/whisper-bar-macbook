import Cocoa
import CoreGraphics

/// Coordina todos los módulos y gestiona la barra de menú.
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Dependencias

    private let config      = Config.shared
    private let recorder    = AudioRecorder()
    private let transcriber = Transcriber()
    private let hotkey      = HotkeyManager()

    private var statusItem: NSStatusItem!

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
    }

    // MARK: - Barra de menú

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon("🎙")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "WhisperBar", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Mantén ⌘⌥S para grabar", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        // Estado de la configuración
        menu.addItem(statusItem(for: config.isWhisperCliValid,
                                ok:  "whisper-cli: \(URL(fileURLWithPath: config.whisperCliPath).lastPathComponent)",
                                err: "❌ whisper-cli no encontrado"))
        menu.addItem(statusItem(for: config.isModelValid,
                                ok:  "Modelo: \(URL(fileURLWithPath: config.modelPath).lastPathComponent)",
                                err: "❌ Modelo no encontrado"))

        let langItem = NSMenuItem(title: "Idioma: \(config.language)", action: nil, keyEquivalent: "")
        langItem.isEnabled = false
        menu.addItem(langItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir", action: #selector(quit), keyEquivalent: "q")

        statusItem.menu = menu
    }

    private func statusItem(for ok: Bool, ok okText: String, err errText: String) -> NSMenuItem {
        let item = NSMenuItem(title: ok ? "✅ \(okText)" : errText, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func setIcon(_ s: String) {
        DispatchQueue.main.async { self.statusItem.button?.title = s }
    }

    // MARK: - Grabación

    private func startRecording() {
        do {
            try recorder.start()
            setIcon("🔴")
        } catch {
            notify("Error al iniciar grabación: \(error.localizedDescription)")
        }
    }

    private func stopAndTranscribe() {
        guard recorder.isRecording else { return }

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            setIcon("🎙")
            return
        }

        setIcon("⏳")
        let audioURL = recorder.outputURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            switch self.transcriber.transcribe(url: audioURL) {
            case .success(let text) where !text.isEmpty:
                self.paste(text: text)
            case .failure(let error):
                self.notify("Error: \(error.localizedDescription)")
                self.setIcon("🎙")
            default:
                self.setIcon("🎙")
            }
        }
    }

    // MARK: - Paste (preserva el clipboard del usuario)

    private func paste(text: String) {
        // Guardar contenido previo del clipboard
        let previous = NSPasteboard.general.string(forType: .string)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Simular ⌘V
        let src  = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restaurar clipboard original tras 300ms (suficiente para que el paste complete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if let previous {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
            self?.setIcon("🎙")
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

    @objc private func quit() { NSApp.terminate(nil) }
}
