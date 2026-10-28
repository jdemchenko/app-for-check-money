import Foundation
import SwiftData

/// Person-level debt: I owe someone, or they owe me.
@Model
final class MoneyDebt {
    @Attribute(.unique) var id: String
    var personName: String
    var amount: Double
    var currencyRaw: String
    /// `iOwe` | `owedToMe`
    var directionRaw: String
    var note: String?
    var createdAt: Date
    var settledAt: Date?
    var accountId: String?

    init(
        id: String = UUID().uuidString,
        personName: String,
        amount: Double,
        currency: AppCurrency = .byn,
        direction: DebtDirection,
        note: String? = nil,
        createdAt: Date = .now,
        settledAt: Date? = nil,
        accountId: String? = nil
    ) {
        self.id = id
        self.personName = personName
        self.amount = max(0, amount)
        self.currencyRaw = currency.rawValue
        self.directionRaw = direction.rawValue
        self.note = note
        self.createdAt = createdAt
        self.settledAt = settledAt
        self.accountId = accountId
    }

    var currency: AppCurrency {
        get { AppCurrency.parse(currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .iOwe }
        set { directionRaw = newValue.rawValue }
    }

    var isSettled: Bool { settledAt != nil }

    func settle(at date: Date = .now) {
        settledAt = date
    }
}

enum DebtDirection: String, CaseIterable, Identifiable, Codable {
    case iOwe
    case owedToMe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iOwe: return L10n.string("debt.iOwe")
        case .owedToMe: return L10n.string("debt.owedToMe")
        }
    }
}
