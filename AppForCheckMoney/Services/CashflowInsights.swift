import Foundation

/// Extra quiet insights on top of `StatsSnapshot` — cashflow shape, not dashboard spam.
struct CashflowInsight: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

enum CashflowInsights {
    static func lines(from snapshot: StatsSnapshot) -> [CashflowInsight] {
        var out: [CashflowInsight] = []
        let ccy = snapshot.displayCurrency.code

        if snapshot.expense > 0, snapshot.income > 0 {
            let burn = snapshot.expense / max(snapshot.income, 0.01)
            let pct = Int((burn * 100).rounded())
            out.append(CashflowInsight(
                id: "burn",
                title: L10n.string("insights.burnRate"),
                detail: String(format: L10n.string("insights.burnRateDetail"), pct)
            ))
        }

        if let prior = snapshot.priorExpense, prior > 0, let delta = snapshot.expenseDelta {
            let pct = Int((delta / prior * 100).rounded())
            let key = pct >= 0 ? "insights.spendUp" : "insights.spendDown"
            out.append(CashflowInsight(
                id: "delta",
                title: L10n.string(key),
                detail: String(
                    format: L10n.string("insights.spendDeltaDetail"),
                    abs(pct),
                    MoneyFormat.currency(abs(delta), code: snapshot.displayCurrency)
                )
            ))
        }

        if snapshot.dailyAverage > 0 {
            out.append(CashflowInsight(
                id: "daily",
                title: L10n.string("insights.dailyAvg"),
                detail: MoneyFormat.currency(snapshot.dailyAverage, code: snapshot.displayCurrency)
                    + " · " + ccy
            ))
        }

        if let top = snapshot.largestExpense, top.share >= 0.28 {
            let pct = Int((top.share * 100).rounded())
            out.append(CashflowInsight(
                id: "top-cat",
                title: L10n.string("insights.topCategory"),
                detail: String(
                    format: L10n.string("insights.topCategoryDetail"),
                    top.name,
                    pct
                )
            ))
        }

        if snapshot.balance < 0 {
            out.append(CashflowInsight(
                id: "neg",
                title: L10n.string("insights.negativeCashflow"),
                detail: MoneyFormat.currency(snapshot.balance, code: snapshot.displayCurrency)
            ))
        }

        return Array(out.prefix(4))
    }
}
