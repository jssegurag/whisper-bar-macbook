import Cocoa
import SwiftUI

/// Arnés de previsualización de UI. Abre las ventanas SwiftUI reales de la app
/// para revisar diseño sin instalar nada.
///
/// Frente a `build.sh` + abrir la app, este arnés:
/// - no instala en ~/Applications ni re-firma el bundle, así que no revoca el
///   permiso de Accesibilidad que macOS quita en cada cambio de firma;
/// - no instancia AppDelegate, así que no registra atajos globales ni pide
///   micrófono ni Accesibilidad;
/// - corre con HOME redirigido (ver preview_ui.sh), así que ni el diccionario ni
///   las preferencias del usuario se tocan al jugar con los controles.
///
/// Solo abre las ventanas que existen en cualquier rama. Las demás se alcanzan
/// desde dentro: el diccionario, por ejemplo, desde su pestaña en Preferencias.
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        open(PreferencesView(),
             title: "Preferencias",
             size: NSSize(width: 620, height: 540),
             origin: NSPoint(x: 80, y: 240))

        open(HistoryView(),
             title: "WhisperBar — Historial",
             size: NSSize(width: 500, height: 540),
             origin: NSPoint(x: 740, y: 240))

        NSApp.activate(ignoringOtherApps: true)
    }

    private func open<V: View>(_ view: V, title: String, size: NSSize, origin: NSPoint) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(size)
        window.setFrameOrigin(origin)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct PreviewApp {
    /// NSApplication.delegate no retiene a su delegate.
    static let delegate = PreviewDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
