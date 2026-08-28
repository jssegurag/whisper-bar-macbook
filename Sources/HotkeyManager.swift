import AppKit
import ApplicationServices

/// Representa una combinación de teclas registrada con sus callbacks.
struct HotkeyCombination {
    let id: String
    let modifiers: NSEvent.ModifierFlags
    /// En modo `toggle` la primera pulsación llama a onKeyDown y la siguiente a
    /// onKeyUp: soltar la tecla no termina nada.
    let mode: HotkeyBinding.Mode
    let onKeyDown: () -> Void
    let onKeyUp: () -> Void
}

/// Gestiona múltiples atajos globales de teclado con matching exacto de modificadores.
/// Soporta ⌘⌥, ⌘⌥⇧, ⌘⌥⌃ etc sin conflictos entre combinaciones.
class HotkeyManager {

    private var combinations: [HotkeyCombination] = []
    private var activeComboId: String?
    /// Combos en modo toggle que están encendidos ahora mismo.
    private var toggledOn: Set<String> = []

    private var flagsMonitor: Any?
    private var retryTimer:   DispatchSourceTimer?

    /// Máscara de modificadores relevantes (ignora caps lock, fn, etc.)
    private let relevantMask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]

    // MARK: - API pública

    /// Registra una combinación de teclas. Llamar ANTES de `setupWhenReady()`.
    func register(id: String, modifiers: NSEvent.ModifierFlags,
                  mode: HotkeyBinding.Mode = .hold,
                  onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        combinations.append(HotkeyCombination(
            id: id, modifiers: modifiers, mode: mode,
            onKeyDown: onKeyDown, onKeyUp: onKeyUp))
    }

    /// Borra lo registrado. Se usa al cambiar los atajos en Preferencias: hay que
    /// volver a registrarlos sin reiniciar la app.
    func unregisterAll() {
        combinations.removeAll()
        activeComboId = nil
        toggledOn.removeAll()
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
        // Solo verifica silenciosamente; la UI de permisos la gestiona AppDelegate
        // para evitar múltiples diálogos simultáneos al arrancar.
        if AXIsProcessTrusted() { startMonitor(); return }
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
                // Ya hay un combo de mantener pulsado activo: se mira si se soltó.
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
                for combo in sorted where current == combo.modifiers {
                    switch combo.mode {
                    case .hold:
                        self.activeComboId = combo.id
                        combo.onKeyDown()
                    case .toggle:
                        // Soltar no cierra nada: la siguiente pulsación es la que
                        // termina. Así se puede dictar largo sin sostener teclas.
                        if self.toggledOn.contains(combo.id) {
                            self.toggledOn.remove(combo.id)
                            combo.onKeyUp()
                        } else {
                            self.toggledOn.insert(combo.id)
                            combo.onKeyDown()
                        }
                    }
                    break
                }
            }
        }
    }
}
