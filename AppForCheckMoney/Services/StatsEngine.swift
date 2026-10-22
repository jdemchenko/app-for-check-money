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

struct DaySpend: Identifiable, Hashable {
    var id: Date { day }
    let day: Date
    /// Expense total in display currency for that calendar day.
    let expense: Double
}

struct StatsSnapshot {
    let period: StatsPeriod
    let displayCurrency: AppCurrency
    let income: Double
    let expense: Double
    var balance: Double { income - expense }
    let categoryBreakdown: [CategorySpend]
    let dailySpend: [DaySpend]
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
    /// Mean daily spend across days that had expense (or calendar days in period).
    let dailyAverage: Double
    let largestExpense: CategorySpend?
    let largestIncomeName: String?
    let largestIncomeAmount: Double?
    /// Prior-period expense for % insight (week/month only).
    let priorExpense: Double?
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

        let priorExpenseValue: Double? = {
            guard let range = period.previousRange(now: now) else { return nil }
            return transactions
                .filter { $0.type == .expense && $0.date >= range.start && $0.date < range.end }
                .reduce(0.0) { $0 + $1.amountIn(displayCurrency) }
        }()
        let expenseDelta: Double? = {
            guard let prior = priorExpenseValue else { return nil }
            return ((expense - prior) * 100).rounded() / 100
        }()

        let cal = Calendar.current
        var byDay: [Date: Double] = [:]
        for tx in filtered where tx.type == .expense {
            let day = cal.startOfDay(for: tx.date)
            byDay[day, default: 0] += tx.amountIn(displayCurrency)
        }
        let daily: [DaySpend] = byDay.keys.sorted().map { day in
            DaySpend(day: day, expense: byDay[day] ?? 0)
        }

        let dailyAverage: Double = {
            let daysWithSpend = daily.filter { $0.expense > 0 }
            guard !daysWithSpend.isEmpty else { return 0 }
            let sum = daysWithSpend.reduce(0.0) { $0 + $1.expense }
            return (sum / Double(daysWithSpend.count) * 100).rounded() / 100
        }()

        let largestExpense = breakdown.first

        var largestIncomeName: String?
        var largestIncomeAmount: Double?
        var incomeByCat: [String: Double] = [:]
        for tx in filtered where tx.type == .income {
            incomeByCat[tx.categoryId, default: 0] += tx.amountIn(displayCurrency)
        }
        if let top = incomeByCat.max(by: { $0.value < $1.value }) {
            largestIncomeAmount = (top.value * 100).rounded() / 100
            largestIncomeName = catMap[top.key]?.displayName() ?? L10n.string("category.unknown")
        }

        return StatsSnapshot(
            period: period,
            displayCurrency: displayCurrency,
            income: income,
            expense: expense,
            categoryBreakdown: breakdown,
            dailySpend: daily,
            transactionCount: filtered.count,
            expenseCount: expenseCount,
            expenseDelta: expenseDelta,
            dailyAverage: dailyAverage,
            largestExpense: largestExpense,
            largestIncomeName: largestIncomeName,
            largestIncomeAmount: largestIncomeAmount,
            priorExpense: priorExpenseValue
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
