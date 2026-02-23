import Cocoa
import SwiftUI

/// Controla el panel flotante de transcripción en tiempo real. Singleton.
/// Implementa NSWindowDelegate para capturar el cierre por el botón X nativo.
class FloatingTranscriptionWindowController: NSObject, NSWindowDelegate {
    static let shared = FloatingTranscriptionWindowController()

    private var panel: NSPanel?
    private var viewModel: FloatingTranscriptionViewModel?

    /// Callback para notificar al AppDelegate que debe actualizar el menú.
    var onWindowStateChanged: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Bandera para evitar recursión entre hideWindow y windowWillClose.
    private var isClosing = false

    func showWindow() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            viewModel?.start()
            onWindowStateChanged?()
            return
        }

        let vm = FloatingTranscriptionViewModel()
        vm.onClose = { [weak self] in self?.hideWindow() }
        self.viewModel = vm

        let hostingController = NSHostingController(
            rootView: FloatingTranscriptionView(viewModel: vm))

        let p = NSPanel(contentViewController: hostingController)
        p.title = "WhisperBar — Transcripción en Vivo"
        p.styleMask = [.nonactivatingPanel, .titled, .closable, .resizable, .utilityWindow]
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.delegate = self

        // Posición: esquina inferior-derecha de la pantalla
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = NSSize(width: 420, height: 140)
            let origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - 20,
                y: screenFrame.minY + 20
            )
            p.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        }

        p.isReleasedWhenClosed = false
        p.makeKeyAndOrderFront(nil)
        self.panel = p

        // Auto-iniciar streaming
        vm.start()
        onWindowStateChanged?()
    }

    func hideWindow() {
        guard !isClosing else { return }
        isClosing = true
        viewModel?.stop()
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
        viewModel = nil
        isClosing = false
        onWindowStateChanged?()
    }

    func toggleWindow() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: - NSWindowDelegate

    /// Captura el cierre por el botón X nativo del NSPanel.
    func windowWillClose(_ notification: Notification) {
        guard !isClosing else { return }
        isClosing = true
        viewModel?.stop()
        // No llamar panel?.orderOut — ya se está cerrando
        panel?.delegate = nil
        panel = nil
        viewModel = nil
        isClosing = false
        onWindowStateChanged?()
    }
}
