import Foundation
import AppKit

/// Una aplicación que se puede añadir a un perfil.
struct AppEntry: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let url: URL
    var isRunning: Bool = false

    var id: String { bundleID }

    /// El icono real del sistema. Se pide al pintar la fila y no al construir la
    /// lista: cargar cien iconos para enseñar diez es trabajo tirado.
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

/// De dónde salen las aplicaciones que ofrece el selector.
///
/// **El usuario nunca escribe un bundle ID.** Un identificador mal tecleado
/// produce un perfil que no se aplica nunca, sin ningún aviso: la app no falla,
/// simplemente no pasa nada, y no hay forma de darse cuenta salvo sospechar. Por
/// eso se elige de una lista con nombre e icono, y el identificador queda por
/// debajo.
///
/// Se ofrecen las instaladas **y** las que estén corriendo. Las segundas hacen
/// falta porque una app lanzada desde fuera de las carpetas habituales —un
/// contenedor de desarrollo, algo en `~/Developer`— no aparecería, y es
/// exactamente el caso de quien más va a usar un perfil de terminal.
enum AppCatalog {

    /// Dónde se buscan las apps instaladas.
    static let searchPaths = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]

    // MARK: - Lógica pura

    /// Une las dos fuentes, quita duplicados y ordena por nombre.
    ///
    /// Cuando una app está en las dos, gana la entrada de la lista de instaladas
    /// —tiene la ruta buena para el icono— pero se queda marcada como en
    /// ejecución, que es lo que el usuario reconoce de un vistazo.
    static func merge(running: [AppEntry], installed: [AppEntry]) -> [AppEntry] {
        let corriendo = Set(running.map(\.bundleID))
        var porID: [String: AppEntry] = [:]
        for app in running + installed {
            // Gluffi no se ofrece: un perfil para nosotros mismos no significa
            // nada, porque el dictado nunca se pega en nuestras ventanas.
            guard app.bundleID != ProfileResolver.ownBundleID else { continue }
            var entrada = app
            entrada.isRunning = corriendo.contains(app.bundleID)
            porID[app.bundleID] = entrada
        }
        return porID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Filtra por nombre, y también por identificador: nadie va a escribir uno,
    /// pero si alguien lo pega desde otro sitio, encontrar la app es mejor que
    /// devolver una lista vacía.
    static func filter(_ apps: [AppEntry], query: String) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.bundleID.localizedCaseInsensitiveContains(q)
        }
    }

    // MARK: - El sistema

    /// Todo lo que se le puede ofrecer al usuario ahora mismo.
    static func available() -> [AppEntry] {
        merge(running: runningApps(), installed: installedApps())
    }

    private static func runningApps() -> [AppEntry] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleID = app.bundleIdentifier,
                  let url = app.bundleURL,
                  // Sin nombre no hay nada que enseñar, y los procesos de fondo
                  // sin interfaz no son sitios donde se dicte.
                  let name = app.localizedName,
                  app.activationPolicy == .regular else { return nil }
            return AppEntry(bundleID: bundleID, name: name, url: url, isRunning: true)
        }
    }

    private static func installedApps() -> [AppEntry] {
        var encontradas: [AppEntry] = []
        for ruta in searchPaths {
            let contenido = (try? FileManager.default.contentsOfDirectory(atPath: ruta)) ?? []
            for nombre in contenido where nombre.hasSuffix(".app") {
                let url = URL(fileURLWithPath: ruta).appendingPathComponent(nombre)
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier else { continue }
                let visible = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? String(nombre.dropLast(4))
                encontradas.append(AppEntry(bundleID: bundleID, name: visible, url: url))
            }
        }
        return encontradas
    }
}
