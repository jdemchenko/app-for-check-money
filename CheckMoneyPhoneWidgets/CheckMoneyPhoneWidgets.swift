import WidgetKit
import SwiftUI

struct CheckMoneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckMoneyEntry {
        CheckMoneyEntry(date: .now, snapshot: .placeholder)
    }

    /// Async WidgetKit API (iOS 17+) — preferred over completion-handler variants.
    func snapshot(in context: Context) async -> CheckMoneyEntry {
        CheckMoneyEntry(date: .now, snapshot: loadSnapshot())
    }

    func timeline(in context: Context) async -> Timeline<CheckMoneyEntry> {
        let entry = CheckMoneyEntry(date: .now, snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadSnapshot() -> SharedWidgetSnapshot {
        SharedWidgetSnapshotStore.load() ?? .empty
    }
}

struct CheckMoneyEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWidgetSnapshot
}

private extension SharedWidgetSnapshot {
    /// Sample series for Widget Gallery / placeholders.
    static var placeholder: SharedWidgetSnapshot {
        .init(
            updatedAt: .now,
            todayExpense: 42,
            monthBalance: 320,
            monthExpense: 180,
            currencySymbol: "Br",
            budgetEnabled: true,
            budgetAmount: 1000,
            budgetSpent: 420,
            recentDailyExpenses: [12, 28, 8, 45, 22, 35, 42]
        )
    }
}

struct CheckMoneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: CheckMoneyEntry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                largeLayout
            default:
                compactLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    /// Small + medium — unchanged glance (no sparkline).
    /// Quiet slate-teal — matches app accent without importing AppTheme.
    private var accent: Color { Color(red: 58 / 255, green: 107 / 255, blue: 110 / 255) }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CheckMoney")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))

            Text(entry.snapshot.currencySymbol + " " + format(entry.snapshot.monthBalance))
                .font(.title2.weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityLabel("Balance")

            HStack(spacing: 4) {
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("−\(entry.snapshot.currencySymbol) \(format(entry.snapshot.todayExpense))")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if entry.snapshot.budgetEnabled, entry.snapshot.budgetAmount > 0 {
                let progress = min(1, max(0, entry.snapshot.budgetSpent / entry.snapshot.budgetAmount))
                ProgressView(value: progress)
                    .tint(accent.opacity(0.7))
            }
        }
    }

    /// Large — left glance + right 7-day spend bars.
    private var largeLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CheckMoney")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.9))

                Text(entry.snapshot.currencySymbol + " " + format(entry.snapshot.monthBalance))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .accessibilityLabel("Balance")

                VStack(alignment: .leading, spacing: 4) {
                    labeledAmount(title: "Today", value: entry.snapshot.todayExpense)
                    labeledAmount(title: "Month", value: entry.snapshot.monthExpense)
                }

                if entry.snapshot.budgetEnabled, entry.snapshot.budgetAmount > 0 {
                    let progress = min(1, max(0, entry.snapshot.budgetSpent / entry.snapshot.budgetAmount))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Budget")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        ProgressView(value: progress)
                            .tint(accent.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            weekBars
                .frame(width: 118)
        }
        .padding(.vertical, 2)
    }

    private func labeledAmount(title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("−\(entry.snapshot.currencySymbol) \(format(value))")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var weekBars: some View {
        let days = paddedDays(entry.snapshot.recentDailyExpenses, count: 7)
        let maxValue = max(days.max() ?? 0, 1)
        let weekTotal = days.reduce(0, +)

        return VStack(alignment: .trailing, spacing: 8) {
            Text("7 days")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(accent.opacity(index == days.count - 1 ? 0.72 : 0.28))
                        .frame(
                            width: 10,
                            height: max(4, CGFloat(value / maxValue) * 72)
                        )
                        .accessibilityLabel("Day \(index + 1)")
                        .accessibilityValue(format(value))
                }
            }
            .frame(height: 76, alignment: .bottom)
            Text("−\(entry.snapshot.currencySymbol) \(format(weekTotal))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Seven day spend")
        .accessibilityValue(format(weekTotal))
    }

    private func paddedDays(_ values: [Double], count: Int) -> [Double] {
        if values.count >= count {
            return Array(values.suffix(count))
        }
        return Array(repeating: 0, count: count - values.count) + values
    }

    private func format(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct CheckMoneyPhoneWidgets: Widget {
    let kind = "CheckMoneyPhoneWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckMoneyProvider()) { entry in
            CheckMoneyWidgetView(entry: entry)
        }
        .configurationDisplayName("CheckMoney")
        .description("Today spend, month balance, and 7-day chart")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct CheckMoneyPhoneWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CheckMoneyPhoneWidgets()
    }
}
