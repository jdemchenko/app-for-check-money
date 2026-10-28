import WidgetKit
import SwiftUI

struct TodaySpendEntry: TimelineEntry {
    let date: Date
    let todayExpense: Double
    let balance: Double
    let currency: SharedCurrencyCode
}

struct TodaySpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySpendEntry {
        TodaySpendEntry(date: .now, todayExpense: 12.5, balance: 100, currency: .byn)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySpendEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySpendEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    func snapshot(in context: Context) async -> TodaySpendEntry {
        makeEntry()
    }

    func timeline(in context: Context) async -> Timeline<TodaySpendEntry> {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry() -> TodaySpendEntry {
        let snap = LocalSyncStore.readSnapshot() ?? .empty
        return TodaySpendEntry(
            date: .now,
            todayExpense: snap.todayExpense,
            balance: snap.balance,
            currency: snap.displayCurrency
        )
    }
}

struct TodaySpendWidgetView: View {
    var entry: TodaySpendEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("−\(SharedMoneyFormat.currency(entry.todayExpense, code: entry.currency))")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text("↓")
                        .font(.caption2)
                    Text(shortAmount(entry.todayExpense))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .minimumScaleFactor(0.5)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("−\(SharedMoneyFormat.currency(entry.todayExpense, code: entry.currency))")
                    .font(.headline.monospacedDigit())
                Text(SharedMoneyFormat.currency(entry.balance, code: entry.currency))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shortAmount(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.0f", value)
    }
}

@main
struct CheckMoneyWatchWidgets: WidgetBundle {
    var body: some Widget {
        TodaySpendWidget()
    }
}

struct TodaySpendWidget: Widget {
    let kind = "TodaySpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySpendProvider()) { entry in
            TodaySpendWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today spend")
        .description("Today’s expenses from CheckMoney.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
