import Cocoa
import AVFoundation
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
    private let pasteTracker = PasteTargetTracker.shared

    /// Bandera de cancelación: impide el paste si el usuario canceló durante transcripción.
    private var isCancelled = false

    /// Monitor global del teclado activo sólo mientras se graba o transcribe.
    private var escKeyMonitor: Any?

    /// Evita mostrar el diálogo de Accesibilidad más de una vez por sesión.
    private var hasPromptedForAccessibility = false
    /// Último problema del corrector avisado en esta sesión.
    private var lastLLMWarning: String?

    // MARK: - Animación de grabación

    private var iconTimer: Timer?
    private var iconPhase: CGFloat = 0

    // MARK: - Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupNotifications()

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
        registerHotkeys()
        NotificationCenter.default.addObserver(
            forName: .gluffiHotkeysChanged, object: nil, queue: .main) { [weak self] _ in
                self?.registerHotkeys()
                self?.rebuildMenu()
        }

        if !config.isValid {
            Notifier.shared.post(AppNotification.setupIncomplete(SetupStatus.current(config)))
        }

        // Verificar actualizaciones de Homebrew en segundo plano (sin bloquear el inicio).
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 8) {
            UpdateChecker.shared.checkForUpdates { hasUpdate in
                guard hasUpdate else { return }
                self.postUpdateNotification()
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

        // El diálogo del sistema dice «concede el permiso en Ajustes», y ahí es
        // donde el usuario se atasca: tras recompilar, Gluffi YA aparece marcada
        // en la lista y el permiso sigue denegado, porque la entrada se ató al
        // binario anterior. Volver a marcarla no arregla nada; hay que quitarla y
        // añadirla otra vez. Sin este aviso, el síntoma es que se dicta y no se
        // pega nada, sin explicación.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard !AXIsProcessTrusted() else { return }
            self?.notifyAccessibilityStale()
        }
    }

    private func notifyAccessibilityStale() {
        Notifier.shared.post(AppNotification.Content(
            title: "Gluffi no puede pegar el texto",
            body: "Falta el permiso de Accesibilidad. Si ya aparece marcada en Ajustes, "
                + "quítala de la lista con «−», vuelve a añadirla y reinicia Gluffi: "
                + "el permiso se ató a la versión anterior de la app.",
            actions: [.configure, .dismiss],
            identifier: "accessibility"))
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.tearDown()
        stopIconAnimation()
        FloatingTranscriptionWindowController.shared.hideWindow()
        PillWindowController.shared.hidePill()
    }

    // MARK: - Barra de menú

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIconState(.idle)
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
        menu.minimumWidth = Theme.menuWidth
        menu.delegate = self

        // Tres accesos rápidos arriba. Reemplazan las cuatro filas que solo
        // recordaban atajos: ahora el atajo se lee al lado de su propia acción.
        let tilesItem = NSMenuItem()
        tilesItem.view = MenuTilesView(tiles: [
            MenuTilesView.Tile(symbol: "mic",
                               label: recordTileLabel,
                               isActive: recorder.isRecording,
                               action: #selector(recordTileTapped),
                               showsWave: recorder.isRecording),
            MenuTilesView.Tile(symbol: "waveform",
                               label: "En vivo",
                               isActive: FloatingTranscriptionWindowController.shared.isVisible,
                               action: #selector(toggleFloatingAction)),
            MenuTilesView.Tile(symbol: "capsule",
                               label: "Píldora",
                               isActive: config.floatingPillEnabled,
                               action: #selector(togglePillAction)),
        ], target: self)
        menu.addItem(tilesItem)

        // Única fila que queda del diagnóstico: nombra qué falta, y lleva a
        // resolverlo. Las otras seis se fueron a la ventana de Configuración.
        let status = SetupStatus.current(config)
        let statusColor = status.needsAttention ? Theme.warnNS : Theme.brandNS
        menu.addItem(row(leading: .symbol("gearshape", tint: statusColor),
                         title: status.menuRowTitle,
                         action: #selector(openSetup),
                         showsChevron: true,
                         trailingDot: statusColor))

        menu.addItem(.separator())

        let activeSnippets = SnippetStore.shared.activeSnippets
        if !activeSnippets.isEmpty {
            let insertItem = row(leading: .symbol("text.badge.plus", tint: nil),
                                 title: "Insertar snippet",
                                 action: nil,
                                 showsChevron: true)
            let submenu = NSMenu()
            submenu.minimumWidth = 210
            for snippet in activeSnippets {
                let item = NSMenuItem(title: snippet.name,
                                      action: #selector(insertSnippet(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = snippet.id.uuidString
                // Los sensibles se marcan: insertarlos no pide autenticación, así
                // que conviene saber qué se está pegando antes de pulsar.
                if snippet.isSensitive {
                    item.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "sensible")
                }
                submenu.addItem(item)
            }
            insertItem.submenu = submenu
            menu.addItem(insertItem)
            menu.addItem(.separator())
        }

        menu.addItem(row(leading: .symbol("clock", tint: nil), title: "Historial…",
                         action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(row(leading: .symbol("character.book.closed", tint: nil), title: "Diccionario…",
                         action: #selector(openDictionary), keyEquivalent: "d"))
        menu.addItem(row(leading: .symbol("text.alignleft", tint: nil), title: "Snippets…",
                         action: #selector(openSnippets), keyEquivalent: "s"))
        menu.addItem(row(leading: .symbol("slider.horizontal.3", tint: nil), title: "Preferencias…",
                         action: #selector(openPreferences), keyEquivalent: ","))

        menu.addItem(.separator())
        menu.addItem(row(leading: .none, title: "Salir de Gluffi",
                         action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    /// Etiqueta del tile de grabar según el estado.
    private var recordTileLabel: String {
        if recorder.isRecording { return "Grabando" }
        return iconState == .idle ? "Grabar" : "Procesando"
    }

    /// Fila con vista propia. El resaltado verde del handoff no se puede lograr
    /// con filas nativas: `NSMenu` usa el color de acento del sistema.
    private func row(leading: MenuRowView.Leading,
                     title: String,
                     action: Selector?,
                     keyEquivalent: String = "",
                     showsChevron: Bool = false,
                     trailingDot: NSColor? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        let glyph = keyEquivalent.isEmpty ? nil : "⌘" + keyEquivalent.uppercased()
        item.view = MenuRowView(leading: leading, title: title,
                                shortcut: glyph, showsChevron: showsChevron,
                                trailingDot: trailingDot)
        return item
    }


    func menuWillOpen(_ menu: NSMenu) {
        // Siempre se refresca: el menú puede abrirse muchas veces antes de que el
        // usuario haga algo, y cada vez la app de destino puede ser otra.
        pasteTargetApp = currentPasteTarget()
    }

    // MARK: - Icono de la barra

    /// Estado que se está mostrando. Los seis estados de la app se comunican con
    /// tres tratamientos del logo (ver MenuBarIcon), no con seis emoji.
    private var iconState: MenuBarIcon.AppState = .idle

    private func setIconState(_ state: MenuBarIcon.AppState) {
        DispatchQueue.main.async {
            self.iconState = state
            self.iconTimer?.invalidate()
            self.iconTimer = nil
            self.iconPhase = 0
            self.renderIcon()

            let treatment = MenuBarIcon.treatment(for: state)
            guard MenuBarIcon.isAnimated(treatment) else { return }
            // 30 fps: suficiente para la onda y el anillo, y no calienta la CPU
            // por un icono de 16 px.
            self.iconTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.iconPhase += treatment == .recording ? 0.22 : 0.34
                self.renderIcon()
                // La onda de la píldora sigue el volumen real: se aprovecha el
                // mismo tic para no montar un segundo temporizador.
                if treatment == .recording {
                    PillWindowController.shared.setMicLevel(self.recorder.currentLevel())
                }
            }
        }
    }

    private func renderIcon() {
        let image = MenuBarIcon.image(treatment: MenuBarIcon.treatment(for: iconState),
                                     phase: iconPhase,
                                     needsSetup: SetupStatus.current(config).needsAttention)
        statusItem.button?.image = image
        statusItem.button?.title = ""
    }

    private func stopIconAnimation() {
        iconTimer?.invalidate()
        iconTimer = nil
    }


    // MARK: - Grabación

    private func startRecording() {
        // Se captura SIEMPRE, no solo si está vacío.
        //
        // Antes se conservaba el valor anterior si existía, y eso convivía con un
        // paste() que ignoraba el destino capturado. Al arreglar paste() para que
        // active la app de destino, un valor rancio dejó de ser inofensivo: abrir
        // el menú deja capturada la app de ese momento, y si luego el usuario
        // cambia de ventana y dicta, el texto se pegaba en la anterior.
        //
        // PasteTargetTracker ya resuelve el caso que motivó el guard original: si
        // el frontmost es una ventana nuestra, devuelve la última app externa.
        pasteTargetApp = currentPasteTarget()
        isCancelled = false
        registerEscMonitor()
        do {
            try recorder.start()
            setIconState(.recording)
            PillWindowController.shared.setState(.recording)
        } catch {
            Notifier.shared.post(AppNotification.recordingFailed(
                permission: AVCaptureDevice.authorizationStatus(for: .audio),
                hasInputDevice: AVCaptureDevice.default(for: .audio) != nil,
                systemMessage: error.localizedDescription))
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
        stopIconAnimation()
        removeEscMonitor()
        resetIdleUI()
    }

    // MARK: - Reescritura del texto transcrito

    /// Aplica diccionario y snippets en ese orden (ver RewritePipeline).
    /// Devuelve el texto intacto si ambos están apagados o vacíos.
    private func applyRewrites(_ text: String) -> String {
        let entries = config.dictionaryEnabled ? CustomDictionary.shared.activeEntries : []
        let rules   = config.snippetsEnabled ? SnippetStore.shared.rules() : []
        let result = RewritePipeline.applyReporting(to: text, dictionary: entries,
                                                  snippetRules: rules)
        // Solo cuenta lo que corrigió un dictado real: el campo de prueba de la
        // ventana del diccionario no debe inflar el contador.
        CustomDictionary.shared.recordUsage(of: result.dictionaryUsed)
        return result.text
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
    /// Vuelta a reposo. `afterDictation` distingue el final de un dictado de un
    /// simple reinicio de UI: la palabra de la píldora solo puede rotar en el
    /// primer caso.
    private func resetIdleUI(afterDictation: Bool = false) {
        if afterDictation {
            PillWindowController.shared.rotateIdleWordAfterDictation()
        }
        resetIdleUIInternal()
    }

    private func resetIdleUIInternal() {
        removeEscMonitor()
        setIconState(.idle)
        PillWindowController.shared.setState(.idle)
        pasteTargetApp = nil
    }

    private func stopAndTranscribe() {
        guard recorder.isRecording else { return }
        stopIconAnimation()

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            resetIdleUI()
            return
        }

        setIconState(.transcribing)
        PillWindowController.shared.setProcessingLabel("Transcribiendo")
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
                self.setIconState(.correcting)
                PillWindowController.shared.setProcessingLabel("Corrigiendo")
                let finalText: String
                switch self.llmProcessor.process(text: text) {
                case .success(let processed):
                    finalText = processed
                case .failure(let llmError):
                    self.reportLLMProblem(llmError)
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
                        self.setIconState(.runningAction)
                        let result = self.actionExecutor.execute(intent)
                        Notifier.shared.post(AppNotification.actionResult(result))
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
                if let content = AppNotification.transcriptionFailed(error) {
                    Notifier.shared.post(content)
                }
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
        stopIconAnimation()

        let duration = recorder.stop()

        guard duration >= config.minRecordingDuration else {
            resetIdleUI()
            return
        }

        setIconState(.translating)
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
                Notifier.shared.post(AppNotification.translationFailed(error.localizedDescription))
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
            // Con opciones vacías, macOS moderno puede ignorar la petición de
            // activación de una app en segundo plano. Pedirla explícitamente es
            // lo que hace que el foco llegue de verdad.
            target.activate(options: [.activateIgnoringOtherApps])
            // 0.12 s no siempre alcanza para que la app destino termine de tomar
            // el foco; si ⌘V llega antes, se pierde.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
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

        // 0.6 s en vez de 0.3: si la app destino todavía no leyó el portapapeles
        // cuando se restaura el contenido anterior, el usuario ve pegado el texto
        // viejo, o nada.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            if let previous {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
            // Único punto donde se vuelve a reposo habiendo dictado de verdad.
            self?.resetIdleUI(afterDictation: true)
            self?.rebuildMenu()
        }
    }

    // MARK: - Notificaciones

    /// Registra los tres atajos desde Config. Se vuelve a llamar cuando el usuario
    /// los cambia en Preferencias, sin reiniciar la app.
    private func registerHotkeys() {
        hotkey.tearDown()
        hotkey.unregisterAll()
        for binding in config.hotkeyBindings {
            switch binding.action {
            case .transcribe:
                hotkey.register(id: "transcribe", modifiers: binding.modifiers, mode: binding.mode,
                                onKeyDown: { [weak self] in
                                    self?.recordingMode = .transcribe
                                    self?.startRecording()
                                },
                                onKeyUp: { [weak self] in self?.stopAndTranscribe() })
            case .translate:
                hotkey.register(id: "translate", modifiers: binding.modifiers, mode: binding.mode,
                                onKeyDown: { [weak self] in
                                    self?.recordingMode = .translate
                                    self?.startRecording()
                                },
                                onKeyUp: { [weak self] in self?.stopAndTranslate() })
            case .floating:
                // Abrir y cerrar es una sola pulsación: aquí no hay «mantener».
                hotkey.register(id: "floating", modifiers: binding.modifiers, mode: .hold,
                                onKeyDown: { [weak self] in self?.toggleFloatingTranscription() },
                                onKeyUp: {})
            }
        }
        hotkey.setupWhenReady()
    }

    /// Conecta los botones de las notificaciones. Se llama al arrancar.
    private func setupNotifications() {
        Notifier.shared.start()
        Notifier.shared.onConfigure = { [weak self] in
            DispatchQueue.main.async { self?.openSetup() }
        }
        Notifier.shared.onRetryRecording = { [weak self] in
            DispatchQueue.main.async { self?.handlePillTap() }
        }
        Notifier.shared.onUpdate = {
            UpdateChecker.shared.upgradeWhisper()
        }
    }

    /// Avisa del problema del corrector **una vez por sesión**.
    ///
    /// Antes se notificaba en cada dictado. Con la corrección activada y sin
    /// modelo, eso es una alerta por cada frase que dictas: deja de ser un aviso y
    /// pasa a ser ruido que se aprende a ignorar.
    ///
    /// Y separa los dos casos: sin configurar es una tarea pendiente, no un fallo.
    private func reportLLMProblem(_ error: Error) {
        let sinConfigurar = !config.isLlmCliValid || !config.isLlmModelValid
        let clave = sinConfigurar ? "notConfigured" : "failed"
        guard lastLLMWarning != clave else { return }
        lastLLMWarning = clave
        Notifier.shared.post(sinConfigurar
            ? AppNotification.llmNotConfigured()
            : AppNotification.llmFailed(error.localizedDescription))
    }

    /// Nombra el paquete con actualización, en vez de mandar a revisar dos
    /// pestañas.
    private func postUpdateNotification() {
        let checker = UpdateChecker.shared
        if case .available(let version) = checker.whisperState {
            Notifier.shared.post(AppNotification.updateAvailable(package: "el motor de voz",
                                                                version: version))
        } else if case .available(let version) = checker.llamaState {
            Notifier.shared.post(AppNotification.updateAvailable(package: "la corrección con IA",
                                                                version: version))
        }
    }

    /// Notificación informativa sin botones. Para todo lo demás hay un caso en
    /// AppNotification con su acción.
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

    /// Tile «Grabar» del menú: mismo flujo que el clic en la píldora.
    @objc private func recordTileTapped() {
        handlePillTap()
    }

    /// Ventana de Configuración: la abre la fila de estado del menú, y más
    /// adelante también las notificaciones y el sidebar de Preferencias.
    @objc private func openSetup() {
        SetupWindowController.shared.showWindow()
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
            Notifier.shared.post(AppNotification.snippetUnreadable(name: snippet.name))
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
