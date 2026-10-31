import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \MoneyTransaction.date, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @ObservedObject private var currencySettings = CurrencySettings.shared
    @State private var period: StatsPeriod = .month

    private var snapshot: StatsSnapshot {
        StatsEngine.snapshot(
            transactions: transactions,
            categories: categories,
            period: period,
            displayCurrency: currencySettings.displayCurrency
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spaceSection) {
                    Picker(L10n.string("stats.period"), selection: $period) {
                        ForEach(StatsPeriod.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    totalsCard
                    if snapshot.expenseCount > 0 || snapshot.income > 0 {
                        insightsSection
                    }

                    if snapshot.categoryBreakdown.isEmpty && snapshot.dailySpend.isEmpty {
                        GlassPanel(padding: 28, corner: AppTheme.cornerMedium) {
                            ContentUnavailableView(
                                L10n.string("stats.empty"),
                                systemImage: "chart.bar",
                                description: Text(L10n.string("stats.emptyHint"))
                            )
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        if !snapshot.dailySpend.isEmpty {
                            dailyChartSection
                        }
                        if !snapshot.top3.isEmpty {
                            top3Section
                        }
                        if !snapshot.categoryBreakdown.isEmpty {
                            categorySection
                        }
                    }

                    Text(CurrencyConverter.ratesFootnote)
                        .font(.caption2)
                        .themeTertiary()
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, AppTheme.spaceGroup)
                .animation(AppTheme.springFluid, value: period)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("tab.stats"))
            .navigationBarTitleDisplayMode(.large)
            .id(currencySettings.displayCurrency.rawValue + period.rawValue)
        }
    }

    private var totalsCard: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: AppTheme.spaceItem) {
                Text(L10n.string("stats.overview"))
                    .font(.footnote.weight(.medium))
                    .themeSecondary()

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(MoneyFormat.currency(snapshot.balance, code: snapshot.displayCurrency))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(snapshot.transactionCount) \(L10n.string("stats.ops"))")
                        .font(.caption.weight(.medium))
                        .themeTertiary()
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("home.income"))
                            .font(.caption)
                            .themeSecondary()
                        Text(MoneyFormat.currency(snapshot.income, code: snapshot.displayCurrency))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("home.expense"))
                            .font(.caption)
                            .themeSecondary()
                        Text(MoneyFormat.currency(snapshot.expense, code: snapshot.displayCurrency))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    Spacer(minLength: 0)
                }

                if let delta = snapshot.expenseDelta, period != .all {
                    let priorLabel = period == .week
                        ? L10n.string("stats.vsLastWeek")
                        : L10n.string("stats.vsLastMonth")
                    let sign = delta > 0 ? "+" : ""
                    Text("\(priorLabel) \(sign)\(MoneyFormat.currency(delta, code: snapshot.displayCurrency))")
                        .font(.caption)
                        .foregroundStyle(delta > 0 ? AppTheme.expense : AppTheme.income)
                }
            }
        }
    }

    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietSectionLabel(text: L10n.string("stats.daily"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                let days = Array(snapshot.dailySpend.suffix(14))
                let maxExpense = max(days.map(\.expense).max() ?? 1, 1)
                if days.isEmpty {
                    Text(L10n.string("stats.dailyEmpty"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if days.count == 1, let only = days.first {
                    // Single day — compact row, not one stretched fat bar.
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(only.day.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 8)
                            Text(MoneyFormat.currency(only.expense, code: snapshot.displayCurrency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .fill(AppTheme.trackFill(colorScheme))
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .fill(AppTheme.trackValue(colorScheme))
                                    .frame(width: max(8, geo.size.width * 0.72))
                            }
                        }
                        .frame(height: 8)
                        .clipShape(AppTheme.continuousRect(AppTheme.radiusControl))
                        .accessibilityLabel(only.day.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue(
                            MoneyFormat.currency(only.expense, code: snapshot.displayCurrency)
                        )
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(days) { day in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(AppTheme.trackValue(colorScheme, emphasized: true))
                                    .frame(
                                        width: days.count <= 4 ? 22 : nil,
                                        height: max(4, CGFloat(day.expense / maxExpense) * 88)
                                    )
                                    .accessibilityLabel(day.day.formatted(date: .abbreviated, time: .omitted))
                                    .accessibilityValue(
                                        MoneyFormat.currency(day.expense, code: snapshot.displayCurrency)
                                    )
                                Text(day.day.formatted(.dateTime.day()))
                                    .font(.system(size: 9).monospacedDigit())
                                    .themeTertiary()
                            }
                            .frame(maxWidth: days.count <= 4 ? 28 : .infinity)
                        }
                        if days.count <= 4 {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 110, alignment: .bottom)
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietSectionLabel(text: L10n.string("stats.insights"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 12) {
                    if let delta = snapshot.expenseDelta, period != .all {
                        let priorLabel = period == .week
                            ? L10n.string("stats.vsLastWeek")
                            : L10n.string("stats.vsLastMonth")
                        let pct: String = {
                            guard let prior = snapshot.priorExpense, prior > 0 else {
                                return ""
                            }
                            let p = ((snapshot.expense - prior) / prior * 1000).rounded() / 10
                            let sign = p > 0 ? "+" : ""
                            return " \(sign)\(p)%"
                        }()
                        insightRow(
                            title: priorLabel,
                            value: {
                                let sign = delta > 0 ? "+" : ""
                                return "\(sign)\(MoneyFormat.currency(delta, code: snapshot.displayCurrency))\(pct)"
                            }(),
                            emphasizeExpense: delta > 0
                        )
                    }

                    if snapshot.dailyAverage > 0 {
                        insightRow(
                            title: L10n.string("stats.dailyAvg"),
                            value: MoneyFormat.currency(
                                snapshot.dailyAverage,
                                code: snapshot.displayCurrency
                            )
                        )
                    }

                    if snapshot.averageCheck > 0 {
                        insightRow(
                            title: L10n.string("stats.avgCheck"),
                            value: MoneyFormat.currency(
                                snapshot.averageCheck,
                                code: snapshot.displayCurrency
                            )
                        )
                    }

                    if let largest = snapshot.largestExpense {
                        insightRow(
                            title: L10n.string("stats.largestExpense"),
                            value: "\(largest.name) · \(MoneyFormat.currency(largest.amount, code: snapshot.displayCurrency))",
                            emphasizeExpense: true
                        )
                    }

                    if let name = snapshot.largestIncomeName,
                       let amount = snapshot.largestIncomeAmount {
                        insightRow(
                            title: L10n.string("stats.largestIncome"),
                            value: "\(name) · \(MoneyFormat.currency(amount, code: snapshot.displayCurrency))",
                            emphasizeExpense: false
                        )
                    }

                    ForEach(CashflowInsights.lines(from: snapshot)) { line in
                        insightRow(title: line.title, value: line.detail)
                    }
                }
            }
        }
    }

    private func insightRow(title: String, value: String, emphasizeExpense: Bool? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .themeSecondary()
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .foregroundStyle(
                    emphasizeExpense == true
                        ? AppTheme.expense
                        : (emphasizeExpense == false ? AppTheme.income : Color.primary)
                )
        }
    }

    private var top3Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietSectionLabel(text: L10n.string("stats.top3"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(snapshot.top3.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 16, alignment: .trailing)
                            Image(systemName: row.symbolName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            Text(row.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(percentLabel(row.share))
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(MoneyFormat.currency(row.amount, code: snapshot.displayCurrency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietSectionLabel(text: L10n.string("stats.byCategory"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(snapshot.categoryBreakdown.prefix(8)) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: row.symbolName)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                Text(row.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(percentLabel(row.share))
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(MoneyFormat.currency(row.amount, code: snapshot.displayCurrency))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(AppTheme.trackFill(colorScheme))
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(AppTheme.trackValue(colorScheme))
                                        .frame(width: max(4, geo.size.width * row.share))
                                }
                            }
                            .frame(height: 6)
                            .clipShape(AppTheme.continuousRect(AppTheme.radiusControl))
                        }
                    }
                }
            }
        }
    }

    private func percentLabel(_ share: Double) -> String {
        let pct = (share * 1000).rounded() / 10
        if pct.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }
}
