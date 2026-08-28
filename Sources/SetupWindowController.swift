import Cocoa
import SwiftUI

/// Ventana de Configuración. Singleton, mismo patrón que las demás.
class SetupWindowController: NSObject, NSWindowDelegate {
    static let shared = SetupWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SetupView(onDone: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Gluffi — Configuración"
        win.styleMask = [.titled, .closable, .miniaturizable]
        // El alto lo fija el contenido: la ventana crece con lo que falte.
        win.setContentSize(hosting.view.fittingSize)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
