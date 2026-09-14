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
    /// Toda la decisión vive aquí, sin NSEvent de por medio, para poder probarla.
    private var matcher = HotkeyMatcher()

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

    /// Los combos tal como los ve el decisor.
    private var combos: [HotkeyMatcher.Combo] {
        combinations.map {
            HotkeyMatcher.Combo(id: $0.id, modifiers: $0.modifiers, mode: $0.mode)
        }
    }

    private func run(_ action: HotkeyMatcher.Action) {
        switch action {
        case .none: break
        case .start(let id):   combinations.first { $0.id == id }?.onKeyDown()
        case .stop(let id):    combinations.first { $0.id == id }?.onKeyUp()
        }
    }

    /// Borra lo registrado. Se usa al cambiar los atajos en Preferencias: hay que
    /// volver a registrarlos sin reiniciar la app.
    func unregisterAll() {
        combinations.removeAll()
        matcher.reset()
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
            let pulsados = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection(self.relevantMask)
            self.run(self.matcher.flagsChanged(to: pulsados, combos: self.combos))
        }

    }
}
