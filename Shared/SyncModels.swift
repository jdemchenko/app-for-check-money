import Foundation

/// App Group id shared by iPhone + Watch (enable App Groups capability in Xcode Signing).
enum CheckMoneyAppGroup {
    static let id = "group.com.jdemchenko.AppForCheckMoney"
    static let snapshotFileName = "watch-snapshot.json"
    static let pendingWatchAddsFileName = "pending-watch-adds.json"
}

/// Lightweight currency codes mirrored from the phone app.
enum SharedCurrencyCode: String, Codable, CaseIterable, Identifiable {
    case byn, rub, usd, eur
    var id: String { rawValue }

    var displaySymbol: String {
        switch self {
        case .byn: return "Br"
        case .rub: return "₽"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var code: String { rawValue.uppercased() }
}

struct SharedCategoryDTO: Codable, Identifiable, Hashable {
    var id: String
    var nameRu: String
    var nameEn: String
    var kindRaw: String
    var symbolName: String
    var colorHex: String
    var sortOrder: Int

    func displayName(isRussian: Bool) -> String {
        isRussian ? nameRu : nameEn
    }
}

struct SharedTransactionDTO: Codable, Identifiable, Hashable {
    var id: String
    var amount: Double
    var typeRaw: String
    var categoryId: String
    var note: String?
    var date: Date
    var createdAt: Date
    var sourceRaw: String
    var currencyRaw: String

    var isExpense: Bool { typeRaw == "expense" }

    var currency: SharedCurrencyCode {
        SharedCurrencyCode(rawValue: currencyRaw) ?? .byn
    }
}

/// Full glance payload pushed phone → watch.
struct WatchSnapshot: Codable, Hashable {
    var updatedAt: Date
    var displayCurrencyRaw: String
    var monthIncome: Double
    var monthExpense: Double
    var todayExpense: Double
    var categories: [SharedCategoryDTO]
    var recent: [SharedTransactionDTO]

    var displayCurrency: SharedCurrencyCode {
        SharedCurrencyCode(rawValue: displayCurrencyRaw) ?? .byn
    }

    var balance: Double { monthIncome - monthExpense }

    static var empty: WatchSnapshot {
        WatchSnapshot(
            updatedAt: .now,
            displayCurrencyRaw: SharedCurrencyCode.byn.rawValue,
            monthIncome: 0,
            monthExpense: 0,
            todayExpense: 0,
            categories: SharedSeed.defaultExpenseCategories,
            recent: []
        )
    }
}

/// Expense created on Watch, awaiting merge into phone SwiftData.
struct WatchPendingAdd: Codable, Identifiable, Hashable {
    var id: String
    var amount: Double
    var categoryId: String
    var note: String?
    var currencyRaw: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Double,
        categoryId: String,
        note: String? = nil,
        currencyRaw: String = SharedCurrencyCode.byn.rawValue,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.note = note
        self.currencyRaw = currencyRaw
        self.createdAt = createdAt
    }
}

enum SharedSeed {
    /// Minimal expense grid for Watch when snapshot is empty.
    static let defaultExpenseCategories: [SharedCategoryDTO] = [
        .init(id: "food", nameRu: "Еда", nameEn: "Food", kindRaw: "expense", symbolName: "fork.knife", colorHex: "8E8E93", sortOrder: 0),
        .init(id: "transport", nameRu: "Транспорт", nameEn: "Transport", kindRaw: "expense", symbolName: "car.fill", colorHex: "8E8E93", sortOrder: 1),
        .init(id: "housing", nameRu: "Жильё", nameEn: "Housing", kindRaw: "expense", symbolName: "house.fill", colorHex: "8E8E93", sortOrder: 2),
        .init(id: "shopping", nameRu: "Одежда", nameEn: "Clothing", kindRaw: "expense", symbolName: "tshirt.fill", colorHex: "8E8E93", sortOrder: 3),
        .init(id: "entertainment", nameRu: "Развлечения", nameEn: "Entertainment", kindRaw: "expense", symbolName: "film.fill", colorHex: "8E8E93", sortOrder: 4),
        .init(id: "telecom", nameRu: "Связь", nameEn: "Tech", kindRaw: "expense", symbolName: "iphone", colorHex: "8E8E93", sortOrder: 5),
        .init(id: "gifts", nameRu: "Подарки", nameEn: "Gifts", kindRaw: "both", symbolName: "gift.fill", colorHex: "8E8E93", sortOrder: 6),
        .init(id: "other-expense", nameRu: "Другое", nameEn: "Other", kindRaw: "expense", symbolName: "circle.fill", colorHex: "8E8E93", sortOrder: 7),
    ]
}

enum SharedMoneyFormat {
    static func currency(_ value: Double, code: SharedCurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        switch code {
        case .byn: return "\(number) Br"
        case .rub: return "\(number) ₽"
        case .usd: return "$\(number)"
        case .eur: return "\(number) €"
        }
    }
}
