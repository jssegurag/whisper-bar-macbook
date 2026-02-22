import Cocoa
import SwiftUI

/// Controla el panel flotante de transcripción en tiempo real. Singleton.
class FloatingTranscriptionWindowController {
    static let shared = FloatingTranscriptionWindowController()

    private var panel: NSPanel?
    private var viewModel: FloatingTranscriptionViewModel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func showWindow() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            viewModel?.start()
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
    }

    func hideWindow() {
        viewModel?.stop()
        panel?.orderOut(nil)
        panel = nil
        viewModel = nil
    }

    func toggleWindow() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
}
