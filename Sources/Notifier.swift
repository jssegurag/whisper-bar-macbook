import Foundation
import UserNotifications

/// Publica las notificaciones y ejecuta sus botones.
///
/// Las categorías se registran una sola vez, derivadas de las acciones de cada
/// contenido: así agregar una notificación con botones nuevos no obliga a
/// acordarse de registrar nada.
///
/// Nota de fidelidad: el handoff dibuja una tarjeta propia de 346 px con el logo
/// dentro. Eso es la aproximación del prototipo al banner del sistema; con
/// UNUserNotificationCenter el aspecto lo pinta macOS y no se puede restyle. Lo
/// que sí se controla —y es lo que importa— son el título, el cuerpo y los
/// botones.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Qué hacer cuando el usuario pulsa cada botón. Lo conecta AppDelegate.
    var onConfigure: (() -> Void)?
    var onRetryRecording: (() -> Void)?
    var onUpdate: (() -> Void)?

    private var registeredCategories: Set<String> = []

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    func post(_ content: AppNotification.Content) {
        registerCategoryIfNeeded(for: content)

        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.body
        notification.categoryIdentifier = content.categoryIdentifier

        let request = UNNotificationRequest(identifier: content.identifier,
                                           content: notification,
                                           trigger: nil)
        let center = UNUserNotificationCenter.current()
        // Mismo identificador que la anterior del mismo tipo: se reemplaza en vez
        // de apilar tres avisos del mismo problema.
        center.removePendingNotificationRequests(withIdentifiers: [content.identifier])
        center.add(request)
    }

    private func registerCategoryIfNeeded(for content: AppNotification.Content) {
        let identifier = content.categoryIdentifier
        guard !registeredCategories.contains(identifier) else { return }
        registeredCategories.insert(identifier)

        let actions = content.actions.map { action in
            UNNotificationAction(identifier: action.rawValue,
                                 title: action.title,
                                 options: action == .dismiss ? [] : [.foreground])
        }
        let category = UNNotificationCategory(identifier: identifier,
                                              actions: actions,
                                              intentIdentifiers: [],
                                              options: [])
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            center.setNotificationCategories(existing.union([category]))
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Sin esto, macOS oculta las notificaciones mientras Gluffi está al frente —
    /// que es justo cuando el usuario acaba de dictar.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch AppNotification.Action(rawValue: response.actionIdentifier) {
        case .configure:      onConfigure?()
        case .retryRecording: onRetryRecording?()
        case .update:         onUpdate?()
        case .dismiss, .none: break
        }
        completionHandler()
    }
}
