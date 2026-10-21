import WidgetKit
import SwiftUI

/// Shared payload shape (file-level so `CheckMoneyEntry` can reference it).
struct WidgetSnapshotPayload: Codable {
    var updatedAt: Date
    var todayExpense: Double
    var monthBalance: Double
    var monthExpense: Double
    var currencySymbol: String
    var budgetEnabled: Bool
    var budgetAmount: Double
    var budgetSpent: Double

    static var placeholder: WidgetSnapshotPayload {
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

/// Loads snapshot without requiring App Groups (Personal Team soft-fail).
enum WidgetBridge {
    static let appGroupID = "group.com.jdemchenko.AppForCheckMoney"
    static let key = "widget.snapshot.v1"

    static func load() -> WidgetSnapshotPayload {
        if let data = groupData() ?? UserDefaults.standard.data(forKey: key),
           let snap = try? JSONDecoder().decode(WidgetSnapshotPayload.self, from: data) {
            return snap
        }
        return .placeholder
    }

    private static func groupData() -> Data? {
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil else { return nil }
        return UserDefaults(suiteName: appGroupID)?.data(forKey: key)
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
    let snapshot: WidgetSnapshotPayload
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
