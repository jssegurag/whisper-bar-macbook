import AppKit

/// Algo a lo que se le puede pegar texto. Existe para que el rastreador se pueda
/// probar sin fabricar NSRunningApplication, que no se puede instanciar a mano.
protocol PasteTargetCandidate: AnyObject {
    var processIdentifier: pid_t { get }
}

extension NSRunningApplication: PasteTargetCandidate {}

/// Recuerda la última app externa que estuvo activa, para saber dónde pegar.
///
/// Hace falta porque nuestras propias ventanas roban el foco: abrir Preferencias,
/// el Historial o los Snippets llama `NSApp.activate`, así que en el momento de
/// dictar el frontmost es WhisperBar. Sin este rastreo, el ⌘V se posteaba a
/// nuestra propia ventana y el texto transcrito se perdía — el historial lo
/// guardaba, pero al editor del usuario no llegaba nada.
final class PasteTargetTracker {

    /// Compartido: AppDelegate lo alimenta y la ventana de Configuración lo
    /// consulta para poder decir a dónde iría el texto ahora mismo.
    static let shared = PasteTargetTracker()


    private let selfPid: pid_t
    private(set) weak var lastExternalApp: PasteTargetCandidate?

    init(selfPid: pid_t = getpid()) {
        self.selfPid = selfPid
    }

    /// Nombre de la app a la que se pegaría ahora. Para diagnóstico.
    var currentTargetName: String? {
        (target(frontmost: NSWorkspace.shared.frontmostApplication) as? NSRunningApplication)?
            .localizedName
    }

    /// Registra una app que acaba de activarse. Ignora la nuestra.
    func record(_ app: PasteTargetCandidate?) {
        guard let app, app.processIdentifier != selfPid else { return }
        lastExternalApp = app
    }

    /// A quién pegarle: el frontmost si es de otro, y si somos nosotros, la última
    /// app externa que se usó.
    func target(frontmost: PasteTargetCandidate?) -> PasteTargetCandidate? {
        if let frontmost, frontmost.processIdentifier != selfPid {
            return frontmost
        }
        return lastExternalApp
    }
}
