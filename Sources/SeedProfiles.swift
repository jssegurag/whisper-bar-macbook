import Foundation
import AppKit

/// Quién sabe qué aplicaciones hay instaladas. Detrás de un protocolo para que
/// la siembra se pueda probar sin depender de qué haya en la máquina que corre
/// las pruebas.
protocol InstalledApps {
    func isInstalled(_ bundleID: String) -> Bool
}

/// El catálogo real del sistema.
struct SystemInstalledApps: InstalledApps {
    func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}

/// Los tres perfiles de fábrica.
///
/// Existen porque una funcionalidad que hay que configurar entera antes de que
/// haga nada no la usa nadie. Quien actualiza se encuentra los tres casos que
/// motivaron todo esto ya resueltos, y puede cambiarlos o borrarlos.
///
/// **Se siembran todas las aplicaciones del catálogo, estén instaladas o no.**
/// La primera versión filtraba contra lo que hubiera en la máquina en el primer
/// arranque, y eso dejaba la funcionalidad coja: quien instalaba Slack al día
/// siguiente no lo veía aparecer, y quien abría la pestaña en una máquina recién
/// montada se encontraba perfiles casi vacíos sin entender para qué servían.
///
/// Un identificador de una app ausente es inofensivo —la coincidencia es exacta,
/// así que nunca casa— y `KnownApps` envía el nombre junto al identificador, así
/// que la lista dice «Slack» y no `com.tinyspeck.slackmacgap`. Ver `KnownApps`.
enum SeedProfiles {

    /// Marca de que ya se sembró. Sin ella, borrar los perfiles los devolvería en
    /// el siguiente arranque, y borrarlos es una decisión del usuario.
    static let doneKey = "profilesSeeded"

    // MARK: - Construcción

    /// Los tres perfiles, con el catálogo entero.
    static func build() -> [Profile] {
        let plantillas: [(String, [KnownApps.Entry], ProfileOverrides)] = [
            ("Terminal e IDE", KnownApps.terminal, terminalOverrides),
            ("Mensajería", KnownApps.messaging, messagingOverrides),
            ("Correo y documentos", KnownApps.writing, writingOverrides),
        ]
        return plantillas.enumerated().map { orden, plantilla in
            let (nombre, apps, overrides) = plantilla
            return Profile(name: nombre, bundleIDs: apps.map(\.bundleID),
                           order: orden, overrides: overrides)
        }
    }

    /// Un comando no quiere mayúscula ni punto —los dos rompen la línea— ni un
    /// corrector reescribiendo banderas. La limpieza se queda en conservadora: en
    /// una terminal, reescribir estructura es más riesgo que ganancia.
    ///
    /// Apaga además el repaso con el modelo del sistema. Es el ajuste más caro
    /// del post-proceso —segundos por dictado— y a un comando no le aporta nada:
    /// es el mayor ahorro que un perfil puede conseguir, justo donde los dictados
    /// son más cortos y la espera se nota más.
    private static var terminalOverrides: ProfileOverrides {
        var o = ProfileOverrides()
        o.initialCapital = false
        o.trailingPeriod = false
        o.spellFix = false
        o.cleanupLevel = .conservador
        o.dictionary = true
        o.snippets = true
        o.systemPolish = false
        return o
    }

    /// En un chat el punto final suena cortante, y ahí es donde más se nota la
    /// limpieza: se habla como se habla. El resto hereda.
    private static var messagingOverrides: ProfileOverrides {
        var o = ProfileOverrides()
        o.trailingPeriod = false
        o.cleanupLevel = .completo
        return o
    }

    /// Un correo se escribe como se escribe: mayúscula, punto y corrector.
    private static var writingOverrides: ProfileOverrides {
        var o = ProfileOverrides()
        o.spellFix = true
        o.initialCapital = true
        o.trailingPeriod = true
        o.cleanupLevel = .completo
        return o
    }

    // MARK: - Siembra

    /// Siembra una sola vez, y solo si no hay perfiles.
    ///
    /// Las dos condiciones hacen falta. La marca evita que borrarlos los
    /// devuelva; la lista vacía evita pisar los de alguien que ya se los hizo con
    /// una versión anterior de este código.
    static func seedIfNeeded(into store: ProfileStore,
                             defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        guard store.profiles.isEmpty else { return }
        store.replaceAll(with: build())
    }
}
