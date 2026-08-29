import Foundation

/// Qué perfil aplica a un dictado.
///
/// **Función pura.** No consulta `NSWorkspace`, ni `ProfileStore`, ni `Config`:
/// recibe el bundle ID y la lista, y devuelve el perfil. Así las reglas de
/// prioridad se prueban sin levantar una ventana ni cambiar de aplicación, que es
/// lo único que hace comprobable un comportamiento que el usuario solo ve de
/// refilón.
///
/// ## De dónde sale el bundle ID
///
/// Del **destino del paste**, capturado al presionar el atajo, no del frontmost
/// al terminar la transcripción. Es la diferencia entre un perfil determinista y
/// uno que aplica medio ajuste de una app y medio de otra si el usuario cambia de
/// ventana mientras whisper corre.
///
/// Eso significa que con una ventana de Gluffi al frente el perfil que aplica es
/// el de la última app externa —la misma a la que va a llegar el texto—, no el
/// global. Es deliberado: pegar en la terminal con el formato del correo es
/// exactamente lo que esta funcionalidad viene a evitar, y dictar desde nuestra
/// propia ventana no cambia dónde acaba el texto.
///
/// ## Por qué la coincidencia es exacta
///
/// Sin comodines, sin prefijos, sin expresiones regulares. Un patrón que empareje
/// de más aplica el perfil equivocado y el usuario no tiene forma de saber por
/// qué su dictado salió raro. Pedirle que añada la app desde una lista es más
/// trabajo una vez y ningún misterio después.
enum ProfileResolver {

    /// El identificador de la app. Se lee del bundle para no repetir una
    /// constante que ya vive en el `Info.plist`.
    static let ownBundleID = Bundle.main.bundleIdentifier ?? "com.user.WhisperBar"

    /// El perfil que gana, o `nil` para usar las preferencias globales.
    ///
    /// Recorre los perfiles **activos** por orden ascendente y devuelve el
    /// primero cuya lista contenga el identificador. El desempate entre órdenes
    /// iguales es por id, no por posición en el arreglo: un resultado que
    /// dependiera del orden de llegada cambiaría solo entre arranques.
    static func resolve(bundleID: String?, among profiles: [Profile]) -> Profile? {
        guard let bundleID, !bundleID.isEmpty, bundleID != ownBundleID else { return nil }
        return profiles
            .filter(\.isActive)
            .sorted { $0.order != $1.order
                        ? $0.order < $1.order
                        : $0.id.uuidString < $1.id.uuidString }
            .first { $0.bundleIDs.contains(bundleID) }
    }
}
