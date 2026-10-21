import SwiftUI

struct TransactionRowView: View {
    let transaction: MoneyTransaction
    let category: MoneyCategory?
    /// When set and different from the tx currency, show a quiet converted hint.
    var displayCurrency: AppCurrency? = nil

    var body: some View {
        HStack(spacing: 14) {
            CategoryGlyph(
                symbolName: category?.symbolName ?? "circle.fill",
                colorHex: category?.colorHex ?? "8E8E93",
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(category?.displayName() ?? L10n.string("category.unknown"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.signed(transaction: transaction))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(
                        transaction.type == .income ? AppTheme.income : Color.primary
                    )
                if let displayCurrency,
                   displayCurrency != transaction.currency {
                    Text(MoneyFormat.currency(
                        transaction.amountIn(displayCurrency),
                        code: displayCurrency
                    ))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if transaction.paymentMethod != .unspecified {
            parts.append(transaction.paymentMethod.title)
        }
        if let note = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            parts.append(note)
        } else {
            parts.append(MoneyFormat.dayLabel(transaction.date))
        }
        return parts.joined(separator: " · ")
    }
}
