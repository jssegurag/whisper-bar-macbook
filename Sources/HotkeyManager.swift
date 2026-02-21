import AppKit
import ApplicationServices

/// Registra un atajo global de teclado (⌘⌥) y notifica al delegado
/// cuando ambos modificadores se presionan (inicio de grabación) o se sueltan (fin).
class HotkeyManager {

    var onKeyDown: (() -> Void)?
    var onKeyUp:   (() -> Void)?

    private let targetModifiers: NSEvent.ModifierFlags = [.command, .option]

    private var flagsMonitor: Any?
    private var retryTimer:   DispatchSourceTimer?
    private var hasPrompted   = false
    private var isActive      = false

    // MARK: - Setup

    func setupWhenReady() {
        checkAndRegister()
    }

    func tearDown() {
        retryTimer?.cancel()
        retryTimer = nil
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        flagsMonitor = nil
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
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let bothPressed = event.modifierFlags
                .intersection(self.targetModifiers) == self.targetModifiers

            if bothPressed && !self.isActive {
                self.isActive = true
                self.onKeyDown?()
            } else if !bothPressed && self.isActive {
                self.isActive = false
                self.onKeyUp?()
            }
        }
    }
}
