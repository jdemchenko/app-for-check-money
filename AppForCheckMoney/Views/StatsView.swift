import SwiftUI
import SwiftData

struct StatsView: View {
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

                    if snapshot.categoryBreakdown.isEmpty {
                        GlassPanel(padding: 28, corner: AppTheme.cornerMedium) {
                            ContentUnavailableView(
                                L10n.string("stats.empty"),
                                systemImage: "chart.bar",
                                description: Text(L10n.string("stats.emptyHint"))
                            )
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        if snapshot.expenseCount > 0 {
                            averageCard
                        }
                        if !snapshot.top3.isEmpty {
                            top3Section
                        }
                        categorySection
                    }

                    Text(CurrencyConverter.ratesFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("tab.stats"))
            .navigationBarTitleDisplayMode(.large)
            .id(currencySettings.displayCurrency.rawValue + period.rawValue)
        }
    }

    private var totalsCard: some View {
        GlassPanel(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string("stats.overview"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(MoneyFormat.currency(snapshot.balance, code: snapshot.displayCurrency))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(snapshot.transactionCount) \(L10n.string("stats.ops"))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("home.income"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(MoneyFormat.currency(snapshot.income, code: snapshot.displayCurrency))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("home.expense"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    private var averageCard: some View {
        GlassPanel(padding: 16, corner: AppTheme.cornerMedium) {
            HStack {
                Text(L10n.string("stats.avgCheck"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(MoneyFormat.currency(snapshot.averageCheck, code: snapshot.displayCurrency))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
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
                                        .fill(Color.primary.opacity(0.06))
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(Color.primary.opacity(0.28))
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
