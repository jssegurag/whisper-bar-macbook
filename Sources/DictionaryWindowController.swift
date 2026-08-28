import Cocoa
import SwiftUI

/// Gestiona la ventana del diccionario personalizado. Singleton para evitar
/// ventanas duplicadas, igual que HistoryWindowController.
class DictionaryWindowController {
    static let shared = DictionaryWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: DictionaryView())
        let win = NSWindow(contentViewController: hostingController)
        win.title = "Gluffi — Diccionario"
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 560, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }
}
