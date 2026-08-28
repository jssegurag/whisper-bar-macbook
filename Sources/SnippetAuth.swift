import Foundation
import LocalAuthentication

/// Puerta de autenticación para ver o editar snippets sensibles.
///
/// Se pide **una vez por sesión de la app**, no por snippet: pedir Touch ID cinco
/// veces seguidas gasta la paciencia del usuario sin ganar seguridad.
///
/// Deliberadamente **no** protege la inserción: al dictar un disparador el valor
/// se pega sin autenticar, porque pedirla en cada dictado haría la funcionalidad
/// inútil. Lo que protege es mirar y editar el valor en la ventana.
final class SnippetAuth {
    static let shared = SnippetAuth()

    /// Resultado de una autenticación previa, válido para el resto de la sesión.
    private(set) var isUnlockedForSession = false

    /// Inyectable para tests: evita disparar el diálogo del sistema.
    var evaluator: (String, @escaping (Bool) -> Void) -> Void = { reason, completion in
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    /// Si este Mac puede autenticar por Touch ID o contraseña del sistema.
    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Pide autenticación si aún no se ha concedido en esta sesión.
    func unlock(reason: String = "Mostrar el contenido de un snippet sensible",
                completion: @escaping (Bool) -> Void) {
        if isUnlockedForSession {
            completion(true)
            return
        }
        evaluator(reason) { [weak self] ok in
            if ok { self?.isUnlockedForSession = true }
            completion(ok)
        }
    }

    /// Vuelve a bloquear. La app la llama al cerrar la ventana de snippets, y los
    /// tests para partir de un estado conocido.
    func lock() {
        isUnlockedForSession = false
    }
}
