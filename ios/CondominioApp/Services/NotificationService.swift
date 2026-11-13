import SwiftUI
import UserNotifications
import UIKit

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    var alertaSolicitado: UUID?
    var unidadeAtiva: String?
    private let centro = UNUserNotificationCenter.current()

    func instalar() { centro.delegate = self }

    func autorizar() async throws -> Bool {
        let settings = await centro.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return try await centro.requestAuthorization(options: [.alert, .sound])
        }
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func agendar(_ alerta: Alerta, em data: Date) async throws -> Bool {
        let settings = await centro.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return false }
        let content = UNMutableNotificationContent()
        content.title = Alerta.tituloPadrao
        content.body = "Há uma mensagem da administração para a sua unidade"
        if settings.soundSetting == .enabled { content.sound = .default }
        content.userInfo = ["alertaID": alerta.id.uuidString, "unidade": alerta.chaveUnidade]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, data.timeIntervalSinceNow), repeats: false)
        try await centro.add(UNNotificationRequest(identifier: identificador(alerta.id), content: content, trigger: trigger))
        return true
    }

    private func identificador(_ id: UUID) -> String { "convivencia-demo-" + id.uuidString }
    func cancelar(_ ids: [UUID]) {
        let requests = ids.map { identificador($0) }
        centro.removePendingNotificationRequests(withIdentifiers: requests)
        centro.removeDeliveredNotifications(withIdentifiers: requests)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = (response.notification.request.content.userInfo["alertaID"] as? String).flatMap(UUID.init(uuidString:))
        Task { @MainActor in self.alertaSolicitado = id }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let unidade = notification.request.content.userInfo["unidade"] as? String
        Task { @MainActor in
            completionHandler(unidade != nil && unidade == self.unidadeAtiva ? [.banner, .sound] : [])
        }
    }
}

final class AlertaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationService.shared.instalar()
        return true
    }
}
