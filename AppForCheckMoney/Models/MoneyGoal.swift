import Foundation
import SwiftData

/// Savings / purchase goal linked to an account (progress = account balance toward target).
@Model
final class MoneyGoal {
    @Attribute(.unique) var id: String
    var name: String
    var accountId: String
    var targetAmount: Double
    /// ISO currency — usually matches the linked account.
    var currencyRaw: String
    var note: String?
    var createdAt: Date
    var isCompleted: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        accountId: String,
        targetAmount: Double,
        currency: AppCurrency = .byn,
        note: String? = nil,
        createdAt: Date = .now,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.accountId = accountId
        self.targetAmount = max(0, targetAmount)
        self.currencyRaw = currency.rawValue
        self.note = note
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }

    var currency: AppCurrency {
        get { AppCurrency.parse(currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    func progress(currentBalance: Double) -> Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, max(0, currentBalance / targetAmount))
    }
}
