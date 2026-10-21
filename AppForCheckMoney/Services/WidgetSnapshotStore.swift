import Foundation
import WidgetKit

/// Publishes Home / balance snapshot for the iPhone widget.
/// Uses Keychain Sharing (Personal Team–safe) — not App Groups.
enum WidgetSnapshotStore {
    typealias Snapshot = SharedWidgetSnapshot

    static func save(_ snapshot: Snapshot) {
        SharedWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "CheckMoneyPhoneWidgets")
    }

    static func load() -> Snapshot? {
        SharedWidgetSnapshotStore.load()
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
