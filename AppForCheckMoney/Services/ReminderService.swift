import Foundation
import UserNotifications

/// Local reminders — Personal Team safe (no push server).
enum ReminderService {
    static let dailyLogId = "checkmoney.daily.log"
    static let recurringPrefix = "checkmoney.recurring."

    /// Backward-compatible alias used by older call sites / docs.
    static let notificationId = dailyLogId

    @MainActor
    static func apply(enabled: Bool, hour: Int, minute: Int = 0) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyLogId])
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
            identifier: dailyLogId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// Schedule “day before” local alerts for active recurring rules.
    @MainActor
    static func scheduleRecurringDayBefore(rules: [RecurringRule]) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        let stale = existing
            .map(\.identifier)
            .filter { $0.hasPrefix(recurringPrefix) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let active = rules.filter(\.isActive)
        guard !active.isEmpty else { return }
        let granted = await requestAuthorization()
        guard granted else { return }

        let cal = Calendar.current
        for rule in active {
            guard let dayBefore = cal.date(byAdding: .day, value: -1, to: rule.nextFireDate) else {
                continue
            }
            // Fire at 10:00 local on the day before.
            var comps = cal.dateComponents([.year, .month, .day], from: dayBefore)
            comps.hour = 10
            comps.minute = 0

            let content = UNMutableNotificationContent()
            content.title = L10n.string("reminder.recurringTitle")
            let amount = MoneyFormat.currency(rule.amount, code: rule.currency)
            let note = rule.note?.isEmpty == false ? rule.note! : L10n.string("recurring.title")
            content.body = String(
                format: L10n.string("reminder.recurringBody"),
                amount,
                note
            )
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: recurringPrefix + rule.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
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
