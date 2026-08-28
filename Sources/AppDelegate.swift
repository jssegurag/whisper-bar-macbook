import Cocoa
import CoreGraphics
import UserNotifications

/// Coordina todos los módulos y gestiona la barra de menú.
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Dependencias

    private let config        = Config.shared
    private let recorder      = AudioRecorder()
    private let transcriber   = Transcriber()
    private let hotkey        = HotkeyManager()
    private let audioFeedback = AudioFeedback()
    private let llmProcessor  = LLMProcessor()
    private let translator      = TranslationProcessor()
    private let actionDetector  = VoiceActionDetector()
    private let actionExecutor  = VoiceActionExecutor()
    private let history       = TranscriptionHistory.shared

    /// Modo de grabación actual (transcripción o traducción)
    private var recordingMode: RecordingMode = .transcribe
    private enum RecordingMode { case transcribe, translate }

    private var statusItem: NSStatusItem!

    /// App destino del paste, capturada al iniciar grabación.
    /// Necesaria porque al hacer click en el pill, aunque el panel sea nonactivating,
    /// la app destino puede perder foco efectivo y Cmd+V no llegaría al editor.
    private var pasteTargetApp: NSRunningApplication?

    /// Recuerda la última app externa activa. Nuestras ventanas roban el foco, así
    /// que sin esto el destino del paste se pierde en cuanto el usuario abre
    /// Preferencias, el Historial o los Snippets.
    private let pasteTracker = PasteTargetTracker()

    /// Bandera de cancelación: impide el paste si el usuario canceló durante transcripción.
    private var isCancelled = false

    /// Monitor global del teclado activo sólo mientras se graba o transcribe.
    private var escKeyMonitor: Any?

    /// Evita mostrar el diálogo de Accesibilidad más de una vez por sesión.
    private var hasPromptedForAccessibility = false

    // MARK: - Animación de grabación

    private var animTimer: Timer?
    private var animPhase: CGFloat = 0

    // MARK: - Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        // Permisos encadenados: cada uno espera al anterior para no solapar diálogos.
        // Si el permiso ya fue concedido, el callback se llama de inmediato (sin diálogo)
        // y la cadena avanza sin mostrar nada al usuario.
        AudioRecorder.requestPermission { [weak self] _ in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.checkAccessibilityPermission()
                }
            }
        }

        // Callback para actualizar menú cuando la ventana flotante cambia de estado
        FloatingTranscriptionWindowController.shared.onWindowStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }

        // Pill flotante de micrófono (toggle de grabación)
        PillWindowController.shared.onPillTapped = { [weak self] in
            DispatchQueue.main.async { self?.handlePillTap() }
        }
        PillWindowController.shared.onPillCancelTapped = { [weak self] in
            DispatchQueue.main.async { self?.cancelRecording() }
        }
        PillWindowController.shared.onPillHiddenByUser = { [weak self] in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }
        if config.floatingPillEnabled {
            PillWindowController.shared.showPill()
        }

        // Transcripción: ⌘⌥
        hotkey.register(id: "transcribe", modifiers: [.command, .option],
            onKeyDown: { [weak self] in
                self?.recordingMode = .transcribe
                self?.startRecording()
            },
            onKeyUp: { [weak self] in self?.stopAndTranscribe() }
        )

        // Traducción: ⌘⌥⇧
        hotkey.register(id: "translate", modifiers: [.command, .option, .shift],
            onKeyDown: { [weak self] in
                self?.recordingMode = .translate
                self?.startRecording()
            },
            onKeyUp: { [weak self] in self?.stopAndTranslate() }
        )

        // Transcripción flotante: ⌘⌥⌃
        hotkey.register(id: "floating", modifiers: [.command, .option, .control],
            onKeyDown: { },
            onKeyUp:   { [weak self] in self?.toggleFloatingTranscription() }
        )

        hotkey.setupWhenReady()

        if !config.isValid {
            notify("⚠️ Configuración incompleta — abre el menú para ver el estado")
        }

        // Verificar actualizaciones de Homebrew en segundo plano (sin bloquear el inicio).
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 8) {
            UpdateChecker.shared.checkForUpdates { hasUpdate in
                guard hasUpdate else { return }
                self.notify("⬆ Hay actualizaciones disponibles — abre Preferencias → Modelos o Corrección LLM")
            }
        }

    }

    private func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted(), !hasPromptedForAccessibility else { return }
        hasPromptedForAccessibility = true

        // AXIsProcessTrustedWithOptions con prompt=true muestra el diálogo nativo
        // del sistema ("Gluffi quiere controlar esta computadora") y abre
        // Configuración del Sistema → Accesibilidad cuando el usuario lo acepta.
        // Activar la app primero garantiza que el diálogo aparezca en primer plano.
        NSApp.activate(ignoringOtherApps: true)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.tearDown()
        stopRecordingAnimation()
        FloatingTranscriptionWindowController.shared.hideWindow()
        PillWindowController.shared.hidePill()
    }

    // MARK: - Barra de menú

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIconEmoji("🎙")
        // Rastrea qué app externa está activa para saber dónde pegar después.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.pasteTracker.record(app)
        }
        pasteTracker.record(NSWorkspace.shared.frontmostApplication)

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Gluffi", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Mantén ⌘⌥ para grabar", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        if config.translationEnabled {
            let target = Config.languageName(for: config.translationTargetLanguage)
            let transHint = NSMenuItem(title: "Mantén ⌘⌥⇧ para traducir → \(target)", action: nil, keyEquivalent: "")
            transHint.isEnabled = false
            menu.addItem(transHint)
        }

        menu.addItem(.separator())

        // Transcripción flotante
        let floatingItem: NSMenuItem
        if config.isWhisperStreamValid {
            let label = FloatingTranscriptionWindowController.shared.isVisible
                ? "⏹ Detener transcripción en vivo"
                : "🔴 Transcripción en tiempo real"
            floatingItem = NSMenuItem(title: label, action: #selector(toggleFloatingAction), keyEquivalent: "t")
            floatingItem.keyEquivalentModifierMask = [.command]
        } else {
            floatingItem = NSMenuItem(title: "Streaming: whisper-stream no encontrado", action: nil, keyEquivalent: "")
            floatingItem.isEnabled = false
        }
        menu.addItem(floatingItem)

        let floatingHint = NSMenuItem(title: "⌘⌥⌃ para toggle rápido", action: nil, keyEquivalent: "")
        floatingHint.isEnabled = false
        menu.addItem(floatingHint)

        menu.addItem(.separator())

        // Pill flotante de micrófono
        let pillTitle = config.floatingPillEnabled
            ? "✓ Pill flotante visible"
            : "🎤 Mostrar pill flotante"
        let pillItem = NSMenuItem(title: pillTitle, action: #selector(togglePillAction), keyEquivalent: "p")
        pillItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(pillItem)

        let pillHint = NSMenuItem(title: "Click en el pill para grabar/transcribir", action: nil, keyEquivalent: "")
        pillHint.isEnabled = false
        menu.addItem(pillHint)

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
                                        err: "❌ llama-completion no encontrado"))
            menu.addItem(statusMenuItem(for: config.isLlmModelValid,
                                        ok:  "LLM Modelo: \(URL(fileURLWithPath: config.llmModelPath).lastPathComponent)",
                                        err: "❌ LLM Modelo no configurado"))
        } else {
            let llmOff = NSMenuItem(title: "LLM: desactivado", action: nil, keyEquivalent: "")
            llmOff.isEnabled = false
            menu.addItem(llmOff)
        }

        if config.isWhisperStreamValid {
            menu.addItem(statusMenuItem(for: true,
                                        ok: "whisper-stream: \(URL(fileURLWithPath: config.whisperStreamPath).lastPathComponent)",
                                        err: ""))
        }

        let langItem = NSMenuItem(title: "Idioma: \(config.language)", action: nil, keyEquivalent: "")
        langItem.isEnabled = false
        menu.addItem(langItem)

        let actionsItem = NSMenuItem(
            title: config.voiceActionsEnabled ? "⚡ Acciones por voz: activadas" : "Acciones por voz: desactivadas",
            action: nil, keyEquivalent: "")
        actionsItem.isEnabled = false
        menu.addItem(actionsItem)

        // Insertar sin dictar: nadie recuerda sus propios comandos a los tres meses.
        let activeSnippets = SnippetStore.shared.activeSnippets
        if !activeSnippets.isEmpty {
            let insertItem = NSMenuItem(title: "Insertar snippet", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for snippet in activeSnippets {
                let item = NSMenuItem(title: snippet.name,
                                      action: #selector(insertSnippet(_:)),
                                      keyEquivalent: "")
                item.representedObject = snippet.id.uuidString
                submenu.addItem(item)
            }
            insertItem.submenu = submenu
            menu.addItem(.separator())
            menu.addItem(insertItem)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferencias…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(withTitle: "Historial…", action: #selector(openHistory), keyEquivalent: "h")
        menu.addItem(withTitle: "Diccionario…", action: #selector(openDictionary), keyEquivalent: "d")
        menu.addItem(withTitle: "Snippets…", action: #selector(openSnippets), keyEquivalent: "s")
        menu.addItem(withTitle: "Salir", action: #selector(quit), keyEquivalent: "q")

        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    /// Captura la app destino al abrir el menú, antes de que el clic pueda mover
    /// el foco. Sin esto, "Insertar snippet" no sabe dónde pegar.
    func menuWillOpen(_ menu: NSMenu) {
        if pasteTargetApp == nil {
            pasteTargetApp = currentPasteTarget()
        }
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
        // Capturar la app destino del paste antes de que cualquier UI nuestra robe foco.
        // Para el shortcut esto es la app del usuario; para el pill la captura ocurre
        // antes en handlePillTap (más fiable) y aquí solo se usa si no se capturó ya.
        if pasteTargetApp == nil {
            pasteTargetApp = currentPasteTarget()
        }
        isCancelled = false
        registerEscMonitor()
        do {
            try recorder.start()
            startRecordingAnimation()
            PillWindowController.shared.setState(.recording)
        } catch {
            notify("Error al iniciar grabación: \(error.localizedDescription)")
            removeEscMonitor()
            PillWindowController.shared.setState(.idle)
            pasteTargetApp = nil
        }
    }

    /// Cancela la grabación o transcripción en curso sin pegar nada.
    func cancelRecording() {
        // Solo cancela si hay una operación activa y no se canceló ya.
        // El guard previo permitía ejecutar la cancelación en estado idle porque
        // `isCancelled == false` siempre es verdadero en arranque.
        guard !isCancelled, recorder.isRecording || audioFeedback.isPlaying else { return }
        isCancelled = true
        if recorder.isRecording {
            recorder.stop()
        }
        transcriber.cancel()
        audioFeedback.stop()
        stopRecordingAnimation()
        removeEscMonitor()
        resetIdleUI()
    }

    // MARK: - Reescritura del texto transcrito

    /// Aplica diccionario y snippets en ese orden (ver RewritePipeline).
    /// Devuelve el texto intacto si ambos están apagados o vacíos.
    private func applyRewrites(_ text: String) -> String {
        let entries = config.dictionaryEnabled ? CustomDictionary.shared.activeEntries : []
        let rules   = config.snippetsEnabled ? SnippetStore.shared.rules() : []
        return RewritePipeline.apply(to: text, dictionary: entries, snippetRules: rules)
    }

    // MARK: - Monitor de tecla Escape

    private func registerEscMonitor() {
        guard escKeyMonitor == nil else { return }
        escKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }  // 53 = Escape
            DispatchQueue.main.async { self?.cancelRecording() }
        }
    }

    private func removeEscMonitor() {
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
    }

    /// App frontmost actual, ignorando WhisperBar mismo (por si el pill robara foco).
    /// Destino del paste: el frontmost si es de otra app, y si el frontmost somos
    /// nosotros —porque el usuario tiene abierta una de nuestras ventanas—, la
    /// última app externa que usó.
    private func currentPasteTarget() -> NSRunningApplication? {
        pasteTracker.target(frontmost: NSWorkspace.shared.frontmostApplication)
            as? NSRunningApplication
    }

    /// Restaura UI a estado idle (icono menubar + pill) y limpia destino del paste.
    private func resetIdleUI() {
        removeEscMonitor()
        setIconEmoji("🎙")
        PillWindowController.shared.setState(.idle)
        pasteTargetApp = nil
    }

    private func stopAndTranscribe() {
        guard recorder.isRecording else { return }
        stopRecordingAnimation()

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            resetIdleUI()
            return
        }

        setIconEmoji("⏳")
        PillWindowController.shared.setState(.transcribing)
        audioFeedback.start()

        let audioURL = recorder.outputURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            switch self.transcriber.transcribe(url: audioURL) {
            case .success(let text) where !text.isEmpty:
                guard !self.isCancelled else {
                    DispatchQueue.main.async { self.audioFeedback.stop() }
                    return
                }
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

                guard !self.isCancelled else { return }

                // Diccionario y snippets: después del LLM, que "corregiría" los
                // términos propios del usuario hacia el español estándar, y antes
                // del detector de acciones, para que "abre Oriuno" reconozca la app.
                let correctedText = self.applyRewrites(finalText)

                // Detección de acciones por voz
                if self.config.voiceActionsEnabled {
                    let intent = self.actionDetector.detect(text: correctedText)
                    switch intent {
                    case .none(let originalText):
                        // Sin acción → paste normal
                        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
                        let entry = TranscriptionEntry(text: originalText, duration: duration, sourceApp: sourceApp)
                        self.history.add(entry)
                        self.paste(text: originalText)
                    default:
                        // Ejecutar acción
                        self.setIconEmoji("⚡")
                        let result = self.actionExecutor.execute(intent)
                        self.notify(result)
                        DispatchQueue.main.async {
                            self.resetIdleUI()
                            self.rebuildMenu()
                        }
                    }
                } else {
                    // Acciones desactivadas → paste normal
                    let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
                    let entry = TranscriptionEntry(text: correctedText, duration: duration, sourceApp: sourceApp)
                    self.history.add(entry)
                    self.paste(text: correctedText)
                }
            case .failure(let error):
                DispatchQueue.main.async { self.audioFeedback.stop() }
                guard !self.isCancelled else { return }
                self.notify("Error: \(error.localizedDescription)")
                self.resetIdleUI()
            default:
                DispatchQueue.main.async { self.audioFeedback.stop() }
                guard !self.isCancelled else { return }
                self.resetIdleUI()
            }
        }
    }

    // MARK: - Traducción

    private func stopAndTranslate() {
        guard recorder.isRecording else { return }
        stopRecordingAnimation()

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            resetIdleUI()
            return
        }

        setIconEmoji("🌐")
        PillWindowController.shared.setState(.transcribing)
        audioFeedback.start()

        let audioURL = recorder.outputURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            switch self.translator.translate(audioURL: audioURL) {
            case .success(let text) where !text.isEmpty:
                DispatchQueue.main.async { self.audioFeedback.stop() }
                guard !self.isCancelled else { return }
                let correctedText = self.applyRewrites(text)
                let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
                let entry = TranscriptionEntry(text: correctedText, duration: duration, sourceApp: sourceApp)
                self.history.add(entry)
                self.paste(text: correctedText)
            case .failure(let error):
                DispatchQueue.main.async { self.audioFeedback.stop() }
                guard !self.isCancelled else { return }
                self.notify("Traducción error: \(error.localizedDescription)")
                self.resetIdleUI()
            default:
                DispatchQueue.main.async { self.audioFeedback.stop() }
                guard !self.isCancelled else { return }
                self.resetIdleUI()
            }
        }
    }

    // MARK: - Transcripción flotante

    private func toggleFloatingTranscription() {
        DispatchQueue.main.async { [weak self] in
            FloatingTranscriptionWindowController.shared.toggleWindow()
            self?.rebuildMenu()
        }
    }

    @objc private func toggleFloatingAction() {
        toggleFloatingTranscription()
    }

    // MARK: - Pill flotante

    /// Acción del menú: alterna visibilidad del pill flotante.
    @objc private func togglePillAction() {
        let wasEnabled = config.floatingPillEnabled
        if wasEnabled, recorder.isRecording {
            // Si el usuario apaga el pill mientras graba, terminamos la grabación
            // limpiamente para que no quede audio huérfano.
            stopAndTranscribe()
        }
        config.floatingPillEnabled = !wasEnabled
        if config.floatingPillEnabled {
            PillWindowController.shared.showPill()
        } else {
            PillWindowController.shared.hidePill()
        }
        rebuildMenu()
    }

    /// Click en el pill: dispatcher único entre iniciar y detener grabación.
    private func handlePillTap() {
        if recorder.isRecording {
            stopAndTranscribe()
        } else {
            // Capturamos aquí (antes de que el click haya tenido tiempo de afectar el foco)
            // para asegurar que el paste posterior llegue al editor del usuario.
            pasteTargetApp = currentPasteTarget()
            recordingMode = .transcribe
            startRecording()
        }
    }

    // MARK: - Paste (preserva el clipboard del usuario)

    private func paste(text: String) {
        // Activar la app destino antes de postear ⌘V. Antes este método ignoraba
        // `pasteTargetApp` por completo y posteaba a lo que estuviera al frente:
        // si el usuario tenía abierta una ventana nuestra, el texto se perdía.
        let target = pasteTargetApp ?? currentPasteTarget()
        if let target, !target.isActive {
            target.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.postPaste(text: text)
            }
            return
        }
        postPaste(text: text)
    }

    private func postPaste(text: String) {
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
            self?.resetIdleUI()
            self?.rebuildMenu()
        }
    }

    // MARK: - Notificaciones

    private func notify(_ msg: String) {
        let content = UNMutableNotificationContent()
        content.title = "Gluffi"
        content.body  = msg
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func openHistory() {
        HistoryWindowController.shared.showWindow()
    }

    @objc private func openDictionary() {
        DictionaryWindowController.shared.showWindow()
    }

    @objc private func openSnippets() {
        SnippetsWindowController.shared.showWindow()
    }

    /// Pega un snippet sin dictar. Insertar no exige autenticación aunque sea
    /// sensible: la puerta protege *ver* el valor, no usarlo.
    @objc private func insertSnippet(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let snippet = SnippetStore.shared.snippets.first(where: { $0.id == id }) else { return }
        do {
            let body = try SnippetStore.shared.body(of: snippet)
            paste(text: body)
        } catch {
            notify("No se pudo leer «\(snippet.name)»: \(error.localizedDescription)")
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
