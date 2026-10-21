import Foundation
import WidgetKit

/// Snapshot for the iPhone home-screen widget.
/// Soft-fails App Groups (Personal Team has no application-groups entitlement).
/// Writes standard defaults always; also writes the suite when a group container exists.
enum WidgetSnapshotStore {
    static let appGroupID = "group.com.jdemchenko.AppForCheckMoney"
    private static let key = "widget.snapshot.v1"

    struct Snapshot: Codable, Hashable {
        var updatedAt: Date
        var todayExpense: Double
        var monthBalance: Double
        var monthExpense: Double
        var currencySymbol: String
        var budgetEnabled: Bool
        var budgetAmount: Double
        var budgetSpent: Double
    }

    /// App Group suite only when the container is available (paid team / capability on).
    private static var groupSuite: UserDefaults? {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil else { return nil }
        return UserDefaults(suiteName: appGroupID)
    }

    static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
        groupSuite?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> Snapshot? {
        if let data = groupSuite?.data(forKey: key)
            ?? UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(Snapshot.self, from: data)
        }
        return nil
    }

    @MainActor
    static func publish(
        transactions: [MoneyTransaction],
        displayCurrency: AppCurrency,
        settings: AppSettingsStore = .shared
    ) {
        let cal = Calendar.current
        let now = Date.now
        let dayStart = cal.startOfDay(for: now)
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return }

        let todayExpense = transactions
            .filter { $0.type == .expense && $0.date >= dayStart }
            .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
        let monthIncome = transactions
            .filter { $0.type == .income && $0.date >= monthStart }
            .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
        let monthExpense = transactions
            .filter { $0.type == .expense && $0.date >= monthStart }
            .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }

        let budgetSpent: Double = {
            guard settings.budgetEnabled else { return 0 }
            let budgetCur = settings.budgetCurrency
            return transactions
                .filter { $0.type == .expense && $0.date >= monthStart }
                .reduce(0.0) { $0 + $1.amountIn(budgetCur) }
        }()

        save(
            Snapshot(
                updatedAt: now,
                todayExpense: todayExpense,
                monthBalance: monthIncome - monthExpense,
                monthExpense: monthExpense,
                currencySymbol: displayCurrency.displaySymbol,
                budgetEnabled: settings.budgetEnabled,
                budgetAmount: settings.budgetAmount,
                budgetSpent: budgetSpent
            )
        )
    }
}
