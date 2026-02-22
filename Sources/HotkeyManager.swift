import AppKit
import ApplicationServices

/// Representa una combinación de teclas registrada con sus callbacks.
struct HotkeyCombination {
    let id: String
    let modifiers: NSEvent.ModifierFlags
    let onKeyDown: () -> Void
    let onKeyUp: () -> Void
}

/// Gestiona múltiples atajos globales de teclado con matching exacto de modificadores.
/// Soporta ⌘⌥, ⌘⌥⇧, ⌘⌥⌃ etc sin conflictos entre combinaciones.
class HotkeyManager {

    private var combinations: [HotkeyCombination] = []
    private var activeComboId: String?

    private var flagsMonitor: Any?
    private var retryTimer:   DispatchSourceTimer?
    private var hasPrompted   = false

    /// Máscara de modificadores relevantes (ignora caps lock, fn, etc.)
    private let relevantMask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    // MARK: - API pública

    /// Registra una combinación de teclas. Llamar ANTES de `setupWhenReady()`.
    func register(id: String, modifiers: NSEvent.ModifierFlags,
                  onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        combinations.append(HotkeyCombination(
            id: id, modifiers: modifiers,
            onKeyDown: onKeyDown, onKeyUp: onKeyUp))
    }

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
        guard flagsMonitor == nil else { return }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let current = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection(self.relevantMask)

            if let activeId = self.activeComboId {
                // Ya hay un combo activo — verificar si se soltó
                if let combo = self.combinations.first(where: { $0.id == activeId }) {
                    if current != combo.modifiers {
                        self.activeComboId = nil
                        combo.onKeyUp()
                    }
                }
            } else {
                // Buscar match exacto — prioridad: más modificadores primero
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
