import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyTransaction.createdAt, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    private var monthTransactions: [MoneyTransaction] {
        let cal = Calendar.current
        let now = Date.now
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return transactions }
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return transactions.filter { $0.date >= start && $0.date <= endOfDay }
    }

    private var income: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double { income - expense }

    private var recent: [MoneyTransaction] {
        Array(transactions.prefix(8))
    }

    private func category(for tx: MoneyTransaction) -> MoneyCategory? {
        categories.first { $0.id == tx.categoryId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("home.balance"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(MoneyFormat.currency(balance))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(balance >= 0 ? .primary : Color(hex: "FF3B30"))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                metricChip(
                                    title: L10n.string("home.income"),
                                    value: MoneyFormat.currency(income),
                                    tint: Color(hex: "34C759")
                                )
                                metricChip(
                                    title: L10n.string("home.expense"),
                                    value: MoneyFormat.currency(expense),
                                    tint: Color(hex: "FF3B30")
                                )
                            }
                            .padding(.top, 8)
                        }
                    }

                    HStack {
                        Text(L10n.string("home.recent"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                    }

                    if recent.isEmpty {
                        GlassCard {
                            ContentUnavailableView(
                                L10n.string("home.empty"),
                                systemImage: "tray",
                                description: Text(L10n.string("home.emptyHint"))
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    } else {
                        GlassCard {
                            LazyVStack(spacing: 0) {
                                ForEach(recent, id: \.id) { tx in
                                    TransactionRowView(transaction: tx, category: category(for: tx))
                                    if tx.id != recent.last?.id {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.string("app.name"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func metricChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
