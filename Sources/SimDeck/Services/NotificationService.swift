import Foundation
import UserNotifications

final class NotificationService {
    func show(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()

        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }

            let updatedSettings = await center.notificationSettings()
            guard updatedSettings.authorizationStatus == .authorized || updatedSettings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try await center.add(request)
        } catch {
            return
        }
    }
}
