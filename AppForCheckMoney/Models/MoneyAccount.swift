import Foundation
import SwiftData

/// Multi-currency wallet / card / cash pot. Transactions optionally belong to an account.
@Model
final class MoneyAccount {
    @Attribute(.unique) var id: String
    var name: String
    var currencyRaw: String
    var spaceId: String
    var sortOrder: Int
    var isArchived: Bool
    var symbolName: String
    /// Opening balance in account currency (can be 0).
    var openingBalance: Double
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        currency: AppCurrency = .byn,
        spaceId: String = SpaceIDs.privateDefault,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        symbolName: String = "banknote",
        openingBalance: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.currencyRaw = currency.rawValue
        self.spaceId = spaceId
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.symbolName = symbolName
        self.openingBalance = openingBalance
        self.createdAt = createdAt
    }

    var currency: AppCurrency {
        get { AppCurrency.parse(currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }
}

enum AccountIDs {
    static let cashBYN = "account-cash-byn"
}
