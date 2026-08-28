import Foundation
import ServiceManagement

/// Abrir Gluffi al iniciar sesión.
///
/// Una app de barra de menú que hay que abrir a mano cada mañana se deja de usar
/// en una semana. Usa `SMAppService`, la API de macOS 13: no toca los elementos
/// de inicio del usuario ni escribe en carpetas del sistema.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Devuelve el error para poder explicarlo, en vez de fallar en silencio.
    /// El caso más común: la app no está en /Applications ni en ~/Applications.
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
