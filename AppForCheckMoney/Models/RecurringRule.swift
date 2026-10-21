import Foundation
import SwiftData

enum RecurringFrequency: String, CaseIterable, Identifiable, Codable {
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return L10n.string("recurring.weekly")
        case .monthly: return L10n.string("recurring.monthly")
        }
    }
}

@Model
final class RecurringRule {
    @Attribute(.unique) var id: String
    var amount: Double
    var typeRaw: String
    var categoryId: String
    var note: String?
    var currencyRaw: String
    var paymentMethodRaw: String
    var frequencyRaw: String
    var nextFireDate: Date
    var isActive: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Double,
        type: TransactionType = .expense,
        categoryId: String,
        note: String? = nil,
        currency: AppCurrency = .byn,
        paymentMethod: PaymentMethod = .unspecified,
        frequency: RecurringFrequency = .monthly,
        nextFireDate: Date = .now,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.categoryId = categoryId
        self.note = note
        self.currencyRaw = currency.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.frequencyRaw = frequency.rawValue
        self.nextFireDate = nextFireDate
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var currency: AppCurrency {
        get { AppCurrency.parse(currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod.parse(paymentMethodRaw) }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    func advanceNextFire(calendar: Calendar = .current) {
        switch frequency {
        case .weekly:
            nextFireDate = calendar.date(byAdding: .weekOfYear, value: 1, to: nextFireDate) ?? nextFireDate
        case .monthly:
            nextFireDate = calendar.date(byAdding: .month, value: 1, to: nextFireDate) ?? nextFireDate
        }
    }
}
