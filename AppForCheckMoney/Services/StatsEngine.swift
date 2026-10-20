import Foundation

struct CategorySpend: Identifiable {
    var id: String { categoryId }
    let categoryId: String
    let name: String
    let symbolName: String
    /// Converted into the display currency.
    let amount: Double
    let share: Double
}

struct StatsSnapshot {
    let period: StatsPeriod
    let displayCurrency: AppCurrency
    let income: Double
    let expense: Double
    var balance: Double { income - expense }
    let categoryBreakdown: [CategorySpend]
    let transactionCount: Int
}

enum StatsEngine {
    static func snapshot(
        transactions: [MoneyTransaction],
        categories: [MoneyCategory],
        period: StatsPeriod,
        displayCurrency: AppCurrency,
        now: Date = .now
    ) -> StatsSnapshot {
        let filtered = transactions.filter { period.contains($0.date, now: now) }
        var income = 0.0
        var expense = 0.0
        var byCategory: [String: Double] = [:]

        for tx in filtered {
            let converted = tx.amountIn(displayCurrency)
            switch tx.type {
            case .income:
                income += converted
            case .expense:
                expense += converted
                byCategory[tx.categoryId, default: 0] += converted
            }
        }

        let totalExpense = max(expense, 0.0001)
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let breakdown: [CategorySpend] = byCategory
            .map { id, amount in
                let cat = catMap[id]
                return CategorySpend(
                    categoryId: id,
                    name: cat?.displayName() ?? L10n.string("category.unknown"),
                    symbolName: cat?.symbolName ?? "circle.fill",
                    amount: amount,
                    share: amount / totalExpense
                )
            }
            .sorted { $0.amount > $1.amount }

        return StatsSnapshot(
            period: period,
            displayCurrency: displayCurrency,
            income: income,
            expense: expense,
            categoryBreakdown: breakdown,
            transactionCount: filtered.count
        )
    }
}
