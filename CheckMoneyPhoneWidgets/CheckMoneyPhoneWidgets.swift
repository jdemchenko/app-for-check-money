import WidgetKit
import SwiftUI

struct CheckMoneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckMoneyEntry {
        CheckMoneyEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckMoneyEntry) -> Void) {
        completion(CheckMoneyEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckMoneyEntry>) -> Void) {
        let entry = CheckMoneyEntry(date: .now, snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> SharedWidgetSnapshot {
        SharedWidgetSnapshotStore.load() ?? .empty
    }
}

struct CheckMoneyEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWidgetSnapshot
}

struct CheckMoneyWidgetView: View {
    var entry: CheckMoneyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CheckMoney")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
                    .tint(.primary.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
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
        .description("Today spend and month balance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CheckMoneyPhoneWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CheckMoneyPhoneWidgets()
    }
}
