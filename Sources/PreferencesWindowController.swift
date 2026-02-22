import Cocoa
import SwiftUI

/// Gestiona la ventana de preferencias. Singleton para evitar ventanas duplicadas.
class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: PreferencesView())
        let win = NSWindow(contentViewController: hostingController)
        win.title = "WhisperBar — Preferencias"
        win.styleMask = [.titled, .closable]
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }
}
