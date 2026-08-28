import Cocoa
import SwiftUI

/// Ventana de snippets. Singleton, mismo patrón que Historial y Diccionario.
class SnippetsWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetsWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SnippetsView())
        let win = NSWindow(contentViewController: hostingController)
        win.title = "WhisperBar — Snippets"
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 600, height: 560))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    /// Al cerrar la ventana se vuelve a bloquear: dejar los sensibles visibles
    /// para toda la vida del proceso sería más de lo que el usuario concedió.
    func windowWillClose(_ notification: Notification) {
        SnippetAuth.shared.lock()
        window = nil
    }
}
