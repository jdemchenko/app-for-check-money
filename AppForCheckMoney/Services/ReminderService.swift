import Foundation
import UserNotifications

/// Optional local “log your day” nudge — no server, Personal Team safe.
enum ReminderService {
    static let notificationId = "checkmoney.daily.log"

    @MainActor
    static func apply(enabled: Bool, hour: Int, minute: Int = 0) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        guard enabled else { return }

        let granted = await requestAuthorization()
        guard granted else { return }

        var date = DateComponents()
        date.hour = max(0, min(23, hour))
        date.minute = max(0, min(59, minute))

        let content = UNMutableNotificationContent()
        content.title = L10n.string("reminder.notificationTitle")
        content.body = L10n.string("reminder.notificationBody")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
}
