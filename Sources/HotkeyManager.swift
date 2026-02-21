import AppKit
import ApplicationServices

/// Registra un atajo global de teclado (⌘⌥S) y notifica al delegado
/// cuando la tecla se presiona (inicio de grabación) o suelta (fin).
class HotkeyManager {

    var onKeyDown: (() -> Void)?
    var onKeyUp:   (() -> Void)?

    // keyCode 1 = tecla S (independiente del layout de teclado)
    private let targetKeyCode:   UInt16               = 1
    private let targetModifiers: NSEvent.ModifierFlags = [.command, .option]

    private var keyDownMonitor: Any?
    private var keyUpMonitor:   Any?
    private var retryTimer:     DispatchSourceTimer?
    private var hasPrompted     = false

    // MARK: - Setup

    /// Inicia el proceso de registro del atajo.
    /// Si aún no hay permiso de Accesibilidad, reintenta cada 2 segundos.
    func setupWhenReady() {
        checkAndRegister()
    }

    /// Elimina los monitores al cerrar la app.
    func tearDown() {
        retryTimer?.cancel()
        retryTimer = nil
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor   { NSEvent.removeMonitor(m) }
        keyDownMonitor = nil
        keyUpMonitor   = nil
    }

    // MARK: - Privado

    private func checkAndRegister() {
        if !hasPrompted {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                as CFDictionary
            hasPrompted = true
            if AXIsProcessTrustedWithOptions(opts) { register(); return }
        } else {
            if AXIsProcessTrusted() { register(); return }
        }
        scheduleRetry()
    }

    private func scheduleRetry() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2)
        timer.setEventHandler { [weak self] in self?.checkAndRegister() }
        timer.resume()
        retryTimer = timer
    }

    private func register() {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  !event.isARepeat,
                  event.keyCode == self.targetKeyCode,
                  event.modifierFlags.contains(self.targetModifiers) else { return }
            self.onKeyDown?()
        }
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self,
                  event.keyCode == self.targetKeyCode,
                  event.modifierFlags.contains(self.targetModifiers) else { return }
            self.onKeyUp?()
        }
    }
}
