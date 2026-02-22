import Cocoa
import SwiftUI

/// Gestiona la ventana de historial. Singleton para evitar ventanas duplicadas.
class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: HistoryView())
        let win = NSWindow(contentViewController: hostingController)
        win.title = "WhisperBar — Historial"
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 500, height: 600))
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }
}
