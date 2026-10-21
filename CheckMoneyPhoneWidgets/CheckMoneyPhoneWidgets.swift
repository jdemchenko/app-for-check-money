import WidgetKit
import SwiftUI

private enum WidgetBridge {
    static let appGroupID = "group.com.jdemchenko.AppForCheckMoney"
    static let key = "widget.snapshot.v1"

    struct Snapshot: Codable {
        var updatedAt: Date
        var todayExpense: Double
        var monthBalance: Double
        var monthExpense: Double
        var currencySymbol: String
        var budgetEnabled: Bool
        var budgetAmount: Double
        var budgetSpent: Double

        static var placeholder: Snapshot {
            .init(
                updatedAt: .now,
                todayExpense: 0,
                monthBalance: 0,
                monthExpense: 0,
                currencySymbol: "Br",
                budgetEnabled: false,
                budgetAmount: 0,
                budgetSpent: 0
            )
        }
    }

    static func load() -> Snapshot {
        let suite = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = suite.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return .placeholder }
        return snap
    }
}

struct CheckMoneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckMoneyEntry {
        CheckMoneyEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckMoneyEntry) -> Void) {
        completion(CheckMoneyEntry(date: .now, snapshot: WidgetBridge.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckMoneyEntry>) -> Void) {
        let entry = CheckMoneyEntry(date: .now, snapshot: WidgetBridge.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CheckMoneyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetBridge.Snapshot
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
