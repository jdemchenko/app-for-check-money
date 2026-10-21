import Foundation
import SwiftData

@Model
final class MoneyTransaction {
    @Attribute(.unique) var id: String
    var amount: Double
    /// "expense" | "income"
    var typeRaw: String
    var categoryId: String
    var note: String?
    var date: Date
    var createdAt: Date
    /// "manual" | "voice"
    var sourceRaw: String
    /// ISO-ish code stored per transaction: byn | rub | usd | eur.
    /// Missing/empty on legacy rows → treated as BYN (never rewritten in bulk).
    var currencyRaw: String = AppCurrency.byn.rawValue
    /// "" | cash | card — empty means unspecified (legacy rows).
    var paymentMethodRaw: String = ""

    init(
        id: String = UUID().uuidString,
        amount: Double,
        type: TransactionType,
        categoryId: String,
        note: String? = nil,
        date: Date = .now,
        createdAt: Date = .now,
        source: EntrySource = .manual,
        currency: AppCurrency = .byn,
        paymentMethod: PaymentMethod = .unspecified
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.categoryId = categoryId
        self.note = note
        self.date = date
        self.createdAt = createdAt
        self.sourceRaw = source.rawValue
        self.currencyRaw = currency.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var currency: AppCurrency {
        get { AppCurrency.parse(currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod.parse(paymentMethodRaw) }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var signedAmount: Double {
        type == .income ? amount : -amount
    }

    /// Amount converted into a display currency (for totals only).
    func amountIn(_ display: AppCurrency) -> Double {
        CurrencyConverter.convert(amount, from: currency, to: display)
    }

    func signedAmountIn(_ display: AppCurrency) -> Double {
        type == .income ? amountIn(display) : -amountIn(display)
    }
}

enum EntrySource: String, Codable {
    case manual
    case voice
}
