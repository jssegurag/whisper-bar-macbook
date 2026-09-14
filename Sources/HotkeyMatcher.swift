import AppKit

/// Decide qué hacer ante los eventos de teclado. Sin `NSEvent`, sin monitores,
/// sin estado global: entra un evento, sale una acción.
///
/// Vive separado de `HotkeyManager` porque los atajos son lo único de la app que
/// no se puede probar desde fuera —hacen falta eventos globales y permiso de
/// Accesibilidad— y a la vez lo que más caro sale romper: un fallo aquí deja la
/// app entera sin responder al teclado.
///
/// Hubo aquí una «tecla añadida» —el atajo más la barra espaciadora— para
/// disparar el modo agente. Se retiró: al probarlo, el segundo que pasa entre
/// pulsar el atajo y pulsar el espacio dejaba al usuario sin saber si estaba
/// dictando o pidiendo. El modo se elige ahora antes, con un interruptor en la
/// píldora. El refactor se queda: la lógica de los atajos era lo único de la app
/// que no se podía probar, y ahora sí.
struct HotkeyMatcher {

    struct Combo: Equatable {
        let id: String
        let modifiers: NSEvent.ModifierFlags
        let mode: HotkeyBinding.Mode
        init(id: String, modifiers: NSEvent.ModifierFlags,
             mode: HotkeyBinding.Mode = .hold) {
            self.id = id
            self.modifiers = modifiers
            self.mode = mode
        }
    }

    enum Action: Equatable {
        case none
        case start(String)
        case stop(String)
    }

    private(set) var activeId: String?
    private(set) var toggledOn: Set<String> = []
    init() {}

    // MARK: - Eventos

    /// Cambió el conjunto de modificadores pulsados.
    mutating func flagsChanged(to pressed: NSEvent.ModifierFlags,
                               combos: [Combo]) -> Action {
        if let activeId {
            guard let combo = combos.first(where: { $0.id == activeId }) else {
                self.activeId = nil
                return .none
            }
            guard pressed != combo.modifiers else { return .none }
            self.activeId = nil
            return .stop(combo.id)
        }

        // Coincidencia exacta, y primero la de más modificadores: ⌘⌥⇧ tiene que
        // ganarle a ⌘⌥, que también encaja en el camino.
        let ordenados = combos.sorted {
            $0.modifiers.rawValue.nonzeroBitCount > $1.modifiers.rawValue.nonzeroBitCount
        }
        guard let combo = ordenados.first(where: { pressed == $0.modifiers }) else {
            return .none
        }
        switch combo.mode {
        case .hold:
            activeId = combo.id
            return .start(combo.id)
        case .toggle:
            // Soltar no cierra nada: la siguiente pulsación es la que termina.
            if toggledOn.contains(combo.id) {
                toggledOn.remove(combo.id)
                return .stop(combo.id)
            }
            toggledOn.insert(combo.id)
            return .start(combo.id)
        }
    }

    mutating func reset() {
        activeId = nil
        toggledOn.removeAll()
    }
}
