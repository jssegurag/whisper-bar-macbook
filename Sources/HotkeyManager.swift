import AppKit
import ApplicationServices

/// Combinación de hotkey registrada con sus callbacks.
struct HotkeyCombination {
    let id: String
    let modifiers: NSEvent.ModifierFlags
    let onKeyDown: () -> Void
    let onKeyUp: () -> Void
}

/// Registra múltiples atajos globales de teclado y notifica sus callbacks
/// cuando los modificadores exactos se presionan o sueltan.
class HotkeyManager {

    private var combinations: [HotkeyCombination] = []
    private var activeComboId: String?

    private var flagsMonitor: Any?
    private var retryTimer:   DispatchSourceTimer?
    private var hasPrompted   = false

    /// Solo estos modificadores se comparan (ignora capsLock, fn, etc.)
    private let relevantMask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    // MARK: - Registro

    /// Registra una combinación de hotkey. Llamar antes de setupWhenReady().
    func register(id: String, modifiers: NSEvent.ModifierFlags,
                  onKeyDown: @escaping () -> Void,
                  onKeyUp: @escaping () -> Void) {
        combinations.append(HotkeyCombination(
            id: id, modifiers: modifiers,
            onKeyDown: onKeyDown, onKeyUp: onKeyUp
        ))
    }

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
            if AXIsProcessTrustedWithOptions(opts) { startMonitor(); return }
        } else {
            if AXIsProcessTrusted() { startMonitor(); return }
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

    private func startMonitor() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }

            // Extraer solo los modificadores relevantes (ignorar fn, capsLock, numLock)
            let current = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection(self.relevantMask)

            if let activeId = self.activeComboId {
                // Hay un combo activo → verificar si se soltó
                if let combo = self.combinations.first(where: { $0.id == activeId }) {
                    if current != combo.modifiers {
                        self.activeComboId = nil
                        combo.onKeyUp()
                    }
                }
            } else {
                // Ningún combo activo → buscar match exacto
                // Prioridad: combos más específicos primero (más modifiers)
                let sorted = self.combinations.sorted {
                    $0.modifiers.rawValue.nonzeroBitCount > $1.modifiers.rawValue.nonzeroBitCount
                }
                for combo in sorted {
                    if current == combo.modifiers {
                        self.activeComboId = combo.id
                        combo.onKeyDown()
                        break
                    }
                }
            }
        }
    }
}
