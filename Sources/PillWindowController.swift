import Cocoa
import SwiftUI

/// Subclase de NSPanel que captura click derecho para mostrar un menú contextual.
/// Necesaria porque NSPanel borderless no propaga rightMouseDown a SwiftUI.
final class PillPanel: NSPanel {
    var onRightClick: ((NSEvent) -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

/// Controla el pill flotante de micrófono. Singleton.
/// Patrón espejado de FloatingTranscriptionWindowController.
final class PillWindowController: NSObject, NSWindowDelegate {
    static let shared = PillWindowController()

    private var panel: PillPanel?
    private let viewModel = PillViewModel()
    private let config = Config.shared

    /// Margen alrededor del contenido para que la sombra no se recorte en las
    /// esquinas rectangulares del panel.
    private let shadowMargin: CGFloat = 14

    /// Tamaño del panel. Arranca con una estimación y se ajusta al contenido real
    /// en cuanto la vista informa su tamaño: el handoff pide que la píldora sea
    /// del ancho de su contenido, con el mismo margen a los dos lados en los tres
    /// estados.
    private var pillSize = CGSize(width: 200, height: 74)

    /// Estado del arrastre: dónde estaba el ratón y dónde la ventana al empezar.
    /// Se mide contra la posición absoluta del ratón en pantalla, no contra la
    /// traslación del gesto: esa es relativa a la vista, y la vista se mueve con
    /// la ventana, así que realimentaba y hacía vibrar la píldora.
    private var dragMouseStart: NSPoint?
    private var dragOriginStart: NSPoint?

    /// Callback disparado cuando el usuario hace click izquierdo en el pill.
    var onPillTapped: (() -> Void)?

    /// Callback disparado cuando el usuario pulsa el botón ✕ del pill.
    var onPillCancelTapped: (() -> Void)?

    /// Callback disparado cuando el usuario oculta el pill desde el menú contextual.
    var onPillHiddenByUser: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Mostrar / Ocultar

    func showPill() {
        if let existing = panel {
            existing.orderFrontRegardless()
            return
        }

        let hosting = NSHostingController(
            rootView: PillView(
                model: viewModel,
                onTap: { [weak self] in self?.onPillTapped?() },
                onCancel: { [weak self] in self?.onPillCancelTapped?() },
                onDrag: { [weak self] in self?.dragToMouse() },
                onDragEnded: { [weak self] in self?.endDrag() },
                onSizeChange: { [weak self] size in self?.resize(to: size) }
            )
        )
        // Fondo transparente del hosting para que solo el círculo sea visible
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        let p = PillPanel(
            contentRect: NSRect(origin: .zero, size: pillSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentViewController = hosting
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        // hasShadow = false: el NSPanel rectangular dibujaría una sombra cuadrada
        // que asoma por las esquinas del Capsule. El glow lo gestiona PillView.
        p.hasShadow = false
        // El arrastre lo gestiona PillView con un umbral de 4 px: con
        // isMovableByWindowBackground, un clic con un temblor de un píxel movía la
        // píldora en lugar de grabar.
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = false
        p.isReleasedWhenClosed = false
        p.delegate = self
        p.onRightClick = { [weak self] _ in self?.showContextMenu() }

        let origin = resolvedOrigin()
        p.setFrame(NSRect(origin: origin, size: pillSize), display: true)
        p.orderFrontRegardless()

        self.panel = p
    }

    func hidePill() {
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
    }

    func togglePill() {
        if isVisible { hidePill() } else { showPill() }
    }

    // MARK: - Estado

    /// Actualiza el estado visual del pill. Thread-safe.
    func setState(_ state: PillState) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.state = state
        }
    }

    /// «Transcribiendo» o «Corrigiendo».
    func setProcessingLabel(_ label: String) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.processingLabel = label
        }
    }

    /// Nivel de voz para la onda. Lo empuja AppDelegate mientras graba.
    func setMicLevel(_ level: CGFloat) {
        viewModel.micLevel = level
    }

    /// Rota la palabra en reposo, si toca. Se llama al volver a reposo **después**
    /// de un dictado: la palabra no se mueve mientras está a la vista.
    func rotateIdleWordAfterDictation() {
        let result = IdleWord.rotate(current: config.idleWordIndex,
                                    lastChange: config.idleWordChangedAt)
        guard result.changed else { return }
        config.idleWordIndex = result.index
        config.idleWordChangedAt = Date()
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.idleWord = IdleWord.word(at: result.index)
        }
    }

    // MARK: - Tamaño y arrastre

    /// Ajusta el panel al contenido, conservando la esquina superior izquierda
    /// para que la píldora no salte al cambiar de estado.
    private func resize(to contentSize: CGSize) {
        // Mientras se arrastra, mover la ventana por un cambio de tamaño la haría
        // saltar bajo el cursor.
        guard dragMouseStart == nil else { return }
        let target = CGSize(width: ceil(contentSize.width) + shadowMargin * 2,
                            height: ceil(contentSize.height) + shadowMargin * 2)
        guard let panel, abs(target.width - pillSize.width) > 0.5
                      || abs(target.height - pillSize.height) > 0.5 else {
            pillSize = target
            return
        }
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        pillSize = target
        let origin = clamp(NSPoint(x: topLeft.x, y: topLeft.y - target.height))
        panel.setFrame(NSRect(origin: origin, size: target), display: true)
    }

    /// Coloca la ventana siguiendo el ratón.
    ///
    /// `NSEvent.mouseLocation` está en coordenadas de pantalla y no cambia porque
    /// la ventana se mueva, así que el desplazamiento se calcula siempre contra el
    /// mismo origen y no hay realimentación.
    private func dragToMouse() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        if dragMouseStart == nil {
            dragMouseStart = mouse
            dragOriginStart = panel.frame.origin
        }
        guard let mouseStart = dragMouseStart, let originStart = dragOriginStart else { return }
        let moved = NSPoint(x: originStart.x + (mouse.x - mouseStart.x),
                            y: originStart.y + (mouse.y - mouseStart.y))
        panel.setFrameOrigin(clamp(moved))
    }

    private func endDrag() {
        dragMouseStart = nil
        dragOriginStart = nil
        if let panel { persistOrigin(panel.frame.origin) }
    }

    /// Mantiene la píldora dentro del área visible: 8 px de margen y 34 px arriba,
    /// para que no quede debajo de la barra de menú.
    private func clamp(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: origin.x + pillSize.width / 2,
                                      y: origin.y + pillSize.height / 2))
        }) ?? NSScreen.main else { return origin }
        let area = screen.visibleFrame
        let minX = area.minX + 8
        let maxX = area.maxX - pillSize.width - 8
        let minY = area.minY + 8
        let maxY = area.maxY - pillSize.height - 34
        return NSPoint(x: min(max(origin.x, minX), max(minX, maxX)),
                       y: min(max(origin.y, minY), max(minY, maxY)))
    }

    // MARK: - Posición

    /// Resuelve el origen a usar: el guardado si es válido, o el default.
    private func resolvedOrigin() -> NSPoint {
        let savedX = config.floatingPillOriginX
        let savedY = config.floatingPillOriginY
        if savedX.isFinite, savedY.isFinite {
            let candidate = NSPoint(x: savedX, y: savedY)
            if isOriginVisible(candidate) { return candidate }
        }
        return defaultOrigin()
    }

    /// Esquina inferior-derecha de la pantalla principal, con margen.
    private func defaultOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let frame = screen.visibleFrame
        return NSPoint(
            x: frame.maxX - pillSize.width - 24,
            y: frame.minY + 80
        )
    }

    /// Verifica que el rect del pill colocado en `origin` esté dentro de alguna pantalla.
    private func isOriginVisible(_ origin: NSPoint) -> Bool {
        let pillRect = NSRect(origin: origin, size: pillSize)
        return NSScreen.screens.contains { $0.frame.intersects(pillRect) }
    }

    @objc private func screenParametersChanged() {
        guard let panel else { return }
        if !isOriginVisible(panel.frame.origin) {
            let newOrigin = defaultOrigin()
            panel.setFrameOrigin(newOrigin)
            persistOrigin(newOrigin)
        }
    }

    private func persistOrigin(_ origin: NSPoint) {
        config.floatingPillOriginX = Double(origin.x)
        config.floatingPillOriginY = Double(origin.y)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        persistOrigin(panel.frame.origin)
    }

    // MARK: - Menú contextual (click derecho)

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Ocultar pill", action: #selector(handleHide), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferencias…", action: #selector(handlePreferences), keyEquivalent: "")
        for item in menu.items { item.target = self }

        if let panel, let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: panel.contentView ?? NSView())
        }
    }

    @objc private func handleHide() {
        config.floatingPillEnabled = false
        hidePill()
        onPillHiddenByUser?()
    }

    @objc private func handlePreferences() {
        DispatchQueue.main.async {
            PreferencesWindowController.shared.showWindow()
        }
    }

    // MARK: - Test helpers

    #if DEBUG
    var debugViewModel: PillViewModel { viewModel }
    #endif
}
