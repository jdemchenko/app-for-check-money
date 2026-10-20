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
    let expenseCount: Int
    /// Average expense check in display currency.
    var averageCheck: Double {
        guard expenseCount > 0 else { return 0 }
        return (expense / Double(expenseCount) * 100).rounded() / 100
    }
    var top3: [CategorySpend] { Array(categoryBreakdown.prefix(3)) }
    /// Expense delta vs prior equal window (week/month). Nil when not applicable.
    let expenseDelta: Double?
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
        var expenseCount = 0
        var byCategory: [String: Double] = [:]

        for tx in filtered {
            let converted = tx.amountIn(displayCurrency)
            switch tx.type {
            case .income:
                income += converted
            case .expense:
                expense += converted
                expenseCount += 1
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

        let expenseDelta: Double? = {
            guard let range = period.previousRange(now: now) else { return nil }
            let priorExpense = transactions
                .filter { $0.type == .expense && $0.date >= range.start && $0.date < range.end }
                .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
            return ((expense - priorExpense) * 100).rounded() / 100
        }()

        return StatsSnapshot(
            period: period,
            displayCurrency: displayCurrency,
            income: income,
            expense: expense,
            categoryBreakdown: breakdown,
            transactionCount: filtered.count,
            expenseCount: expenseCount,
            expenseDelta: expenseDelta
        )
    }

    /// Day total + category share right after a quiet save (DeepSeek-style feedback, no toast).
    static func quietFeedback(
        after tx: MoneyTransaction,
        all: [MoneyTransaction],
        categories: [MoneyCategory],
        displayCurrency: AppCurrency,
        now: Date = .now
    ) -> (dayTotal: Double, categoryName: String, categoryPercent: Double) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? now
        let dayTx = all.filter { $0.type == .expense && $0.date >= dayStart && $0.date < dayEnd }
        let dayTotal = dayTx.reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
        let catTotal = dayTx
            .filter { $0.categoryId == tx.categoryId }
            .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
        let percent = dayTotal > 0 ? (catTotal / dayTotal * 1000).rounded() / 10 : 100
        let name = categories.first { $0.id == tx.categoryId }?.displayName()
            ?? L10n.string("category.unknown")
        return (dayTotal, name, percent)
    }
}
