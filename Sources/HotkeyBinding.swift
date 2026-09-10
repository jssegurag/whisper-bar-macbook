import AppKit

/// Un atajo configurable.
///
/// Los tres atajos eran fijos y la pestaña de Atajos era de solo lectura: se
/// mostraban ⌘⌥, ⌘⌥⇧ y ⌘⌥⌃ sin poder cambiarlos. Y `⌘⌥` choca con atajos de
/// otras apps sin que el usuario pudiera hacer nada.
struct HotkeyBinding: Equatable {

    /// Cómo se activa.
    enum Mode: String, CaseIterable, Identifiable {
        /// Mantener pulsado mientras hablas. Es el original.
        case hold
        /// Pulsar una vez para empezar y otra para terminar.
        case toggle

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hold:   return "Mantener pulsado"
            case .toggle: return "Pulsar una vez"
            }
        }

        var explanation: String {
            switch self {
            case .hold:   return "Habla mientras lo mantienes. Al soltar, transcribe."
            case .toggle: return "Púlsalo para empezar y vuelve a pulsarlo para terminar. Mejor para dictados largos."
            }
        }
    }

    enum Action: String, CaseIterable, Identifiable {
        case transcribe, translate, floating

        var id: String { rawValue }

        var title: String {
            switch self {
            case .transcribe: return "Dictar"
            case .translate:  return "Dictar y traducir"
            case .floating:   return "Transcripción en vivo"
            }
        }

        var purpose: String {
            switch self {
            case .transcribe: return "Graba tu voz y pega el texto donde esté el cursor."
            case .translate:  return "Igual, pero traduce antes de pegar."
            case .floating:   return "Abre y cierra la ventana que muestra el texto mientras hablas."
            }
        }

        /// Solo las acciones de dictado admiten los dos modos: la ventana en vivo
        /// se abre y se cierra, no se mantiene pulsada.
        var supportsModes: Bool { self != .floating }

        var defaultModifiers: NSEvent.ModifierFlags {
            switch self {
            case .transcribe: return [.command, .option]
            case .translate:  return [.command, .option, .shift]
            case .floating:   return [.command, .option, .control]
            }
        }
    }

    let action: Action
    var modifiers: NSEvent.ModifierFlags
    var mode: Mode

    // MARK: - Presentación

    /// Los símbolos en el orden de macOS: ⌃⌥⇧⌘.
    static func glyphs(for modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option)  { result += "⌥" }
        if modifiers.contains(.shift)   { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }

    var glyphs: String { HotkeyBinding.glyphs(for: modifiers) }

    // MARK: - Validación

    enum Validation: Equatable {
        case ok
        /// Un solo modificador se dispararía constantemente: ⌘ se usa a cada rato.
        case tooFew
        case conflict(with: Action)

        var message: String? {
            switch self {
            case .ok: return nil
            case .tooFew:
                return "Hace falta combinar al menos dos teclas. Con una sola, el atajo se dispararía todo el tiempo."
            case .conflict(let action):
                return "Esa combinación ya la usa «\(action.title)»."
            }
        }
    }

    /// `others` son los atajos de las demás acciones.
    static func validate(_ modifiers: NSEvent.ModifierFlags,
                         for action: Action,
                         others: [HotkeyBinding]) -> Validation {
        let relevant = modifiers.intersection([.command, .option, .shift, .control])
        guard relevant.rawValue.nonzeroBitCount >= 2 else { return .tooFew }
        if let clash = others.first(where: { $0.action != action && $0.modifiers == relevant }) {
            return .conflict(with: clash.action)
        }
        return .ok
    }
}

/// La composición de un atajo mientras el usuario tiene teclas pulsadas.
///
/// Existe separado de la vista porque la secuencia de eventos no es evidente y
/// era justo donde estaba el fallo. `flagsChanged` llega al pulsar **y al
/// soltar**, así que componer ⌃⇧ produce cuatro eventos:
///
///     ⌃  ·  ⌃⇧  ·  ⌃  ·  (nada)
///
/// Validando cada uno, el tercero —una sola tecla, ya de bajada— encendía el
/// aviso «hace falta combinar al menos dos teclas» sobre un atajo que se había
/// guardado bien en el segundo. El atajo quedaba correcto y la pantalla decía
/// que no. Por eso aquí solo se acumula, y se decide al soltar.
struct ShortcutCapture {

    enum Outcome: Equatable {
        /// Sigue componiendo: no se valida ni se guarda todavía.
        case composing(NSEvent.ModifierFlags)
        /// Soltó todo. Esto es lo que hay que validar y guardar.
        case finished(NSEvent.ModifierFlags)
    }

    /// La combinación más completa vista en esta pulsación.
    private(set) var best: NSEvent.ModifierFlags = []

    static let tracked: [NSEvent.ModifierFlags] = [.command, .option, .shift, .control]

    static func count(_ modifiers: NSEvent.ModifierFlags) -> Int {
        tracked.filter { modifiers.contains($0) }.count
    }

    /// Solo los cuatro modificadores que nos interesan, sin la parte de hardware
    /// (izquierda/derecha), que llega en el mismo campo.
    static func normalize(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection(.deviceIndependentFlagsMask)
             .intersection([.command, .option, .shift, .control])
    }

    /// Un evento de `flagsChanged` ya normalizado.
    mutating func feed(_ pressed: NSEvent.ModifierFlags) -> Outcome {
        guard !pressed.isEmpty else { return .finished(best) }
        // Solo crece. La bajada no puede reducir lo compuesto.
        if ShortcutCapture.count(pressed) > ShortcutCapture.count(best) {
            best = pressed
        }
        return .composing(best)
    }

    mutating func reset() { best = [] }
}
