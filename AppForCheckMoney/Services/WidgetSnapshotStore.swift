import Foundation
import WidgetKit

/// Publishes Home / balance snapshot for the iPhone widget.
/// Uses Keychain Sharing (Personal Team–safe) — not App Groups.
enum WidgetSnapshotStore {
    typealias Snapshot = SharedWidgetSnapshot
    /// Days included in the large-widget sparkline (oldest → newest).
    static let recentDayCount = 7

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
        settings: AppSettingsStore
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

        let recentDaily = recentDailyExpenses(
            transactions: transactions,
            displayCurrency: displayCurrency,
            endingAt: dayStart,
            dayCount: recentDayCount,
            calendar: cal
        )

        save(
            Snapshot(
                updatedAt: now,
                todayExpense: todayExpense,
                monthBalance: monthIncome - monthExpense,
                monthExpense: monthExpense,
                currencySymbol: displayCurrency.displaySymbol,
                budgetEnabled: settings.budgetEnabled,
                budgetAmount: settings.budgetAmount,
                budgetSpent: budgetSpent,
                recentDailyExpenses: recentDaily
            )
        )
    }

    /// Expense totals per calendar day for the last `dayCount` days (oldest → newest).
    static func recentDailyExpenses(
        transactions: [MoneyTransaction],
        displayCurrency: AppCurrency,
        endingAt dayStart: Date,
        dayCount: Int,
        calendar: Calendar = .current
    ) -> [Double] {
        guard dayCount > 0 else { return [] }
        guard let windowStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: dayStart) else {
            return Array(repeating: 0, count: dayCount)
        }
        var totals = Array(repeating: 0.0, count: dayCount)
        for tx in transactions where tx.type == .expense {
            let day = calendar.startOfDay(for: tx.date)
            guard day >= windowStart, day <= dayStart else { continue }
            let offset = calendar.dateComponents([.day], from: windowStart, to: day).day ?? 0
            guard offset >= 0, offset < dayCount else { continue }
            totals[offset] += tx.amountIn(displayCurrency)
        }
        return totals
    }
}
