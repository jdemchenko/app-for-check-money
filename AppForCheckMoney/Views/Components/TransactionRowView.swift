import SwiftUI

struct TransactionRowView: View {
    let transaction: MoneyTransaction
    let category: MoneyCategory?

    var body: some View {
        HStack(spacing: 12) {
            CategoryGlyph(
                symbolName: category?.symbolName ?? "circle.fill",
                colorHex: category?.colorHex ?? "8E8E93"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(category?.displayName() ?? L10n.string("category.unknown"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                     ?? MoneyFormat.dayLabel(transaction.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.signed(transaction.amount, type: transaction.type))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.type == .income ? Color(hex: "34C759") : .primary)
                if transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil {
                    Text(MoneyFormat.dayLabel(transaction.date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
