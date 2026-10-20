import Foundation

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
    /// Keyword bank for SharedVoiceParser (synced from phone SwiftData).
    var keywords: [String]

    init(
        id: String,
        nameRu: String,
        nameEn: String,
        kindRaw: String,
        symbolName: String,
        colorHex: String,
        sortOrder: Int,
        keywords: [String] = []
    ) {
        self.id = id
        self.nameRu = nameRu
        self.nameEn = nameEn
        self.kindRaw = kindRaw
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.keywords = keywords
    }

    enum CodingKeys: String, CodingKey {
        case id, nameRu, nameEn, kindRaw, symbolName, colorHex, sortOrder, keywords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameRu = try c.decode(String.self, forKey: .nameRu)
        nameEn = try c.decode(String.self, forKey: .nameEn)
        kindRaw = try c.decode(String.self, forKey: .kindRaw)
        symbolName = try c.decode(String.self, forKey: .symbolName)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }

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

/// Transaction created on Watch, awaiting merge into phone SwiftData.
struct WatchPendingAdd: Codable, Identifiable, Hashable {
    var id: String
    var amount: Double
    var categoryId: String
    var note: String?
    var currencyRaw: String
    var typeRaw: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Double,
        categoryId: String,
        note: String? = nil,
        currencyRaw: String = SharedCurrencyCode.byn.rawValue,
        typeRaw: String = "expense",
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.note = note
        self.currencyRaw = currencyRaw
        self.typeRaw = typeRaw
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, categoryId, note, currencyRaw, typeRaw, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        amount = try c.decode(Double.self, forKey: .amount)
        categoryId = try c.decode(String.self, forKey: .categoryId)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        currencyRaw = try c.decode(String.self, forKey: .currencyRaw)
        typeRaw = try c.decodeIfPresent(String.self, forKey: .typeRaw) ?? "expense"
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

enum SharedSeed {
    /// Minimal expense grid for Watch when snapshot is empty (with keyword bank for dictation).
    static let defaultExpenseCategories: [SharedCategoryDTO] = [
        .init(id: "food", nameRu: "Еда", nameEn: "Food", kindRaw: "expense", symbolName: "fork.knife", colorHex: "8E8E93", sortOrder: 0,
              keywords: ["еда", "food", "кофе", "coffee", "обед", "lunch", "ужин", "dinner", "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe", "продукт", "продукты", "grocery", "пицца", "pizza", "бургер", "burger", "картошк", "огурц", "гарнир"]),
        .init(id: "transport", nameRu: "Транспорт", nameEn: "Transport", kindRaw: "expense", symbolName: "car.fill", colorHex: "8E8E93", sortOrder: 1,
              keywords: ["транспорт", "transport", "азс", "azs", "заправка", "бензин", "топливо", "gas", "fuel", "taxi", "такси", "метро", "metro", "автобус", "bus", "парковка", "parking", "проезд", "uber"]),
        .init(id: "housing", nameRu: "Жильё", nameEn: "Housing", kindRaw: "expense", symbolName: "house.fill", colorHex: "8E8E93", sortOrder: 2,
              keywords: ["жильё", "жилье", "housing", "аренда", "rent", "квартира", "apartment", "коммуналка", "utilities"]),
        .init(id: "shopping", nameRu: "Одежда", nameEn: "Clothing", kindRaw: "expense", symbolName: "tshirt.fill", colorHex: "8E8E93", sortOrder: 3,
              keywords: ["одежда", "clothing", "clothes", "шопинг", "shopping"]),
        .init(id: "entertainment", nameRu: "Развлечения", nameEn: "Entertainment", kindRaw: "expense", symbolName: "film.fill", colorHex: "8E8E93", sortOrder: 4,
              keywords: ["развлечения", "entertainment", "кино", "cinema", "кинотеатр"]),
        .init(id: "telecom", nameRu: "Связь", nameEn: "Tech", kindRaw: "expense", symbolName: "iphone", colorHex: "8E8E93", sortOrder: 5,
              keywords: ["связь", "телефон", "phone", "mobile", "интернет", "sim"]),
        .init(id: "gifts", nameRu: "Подарки", nameEn: "Gifts", kindRaw: "both", symbolName: "gift.fill", colorHex: "8E8E93", sortOrder: 6,
              keywords: ["подарок", "подарки", "gift", "gifts"]),
        .init(id: "other-expense", nameRu: "Другое", nameEn: "Other", kindRaw: "expense", symbolName: "circle.fill", colorHex: "8E8E93", sortOrder: 7,
              keywords: ["другое", "other", "разное", "misc"]),
        .init(id: "salary", nameRu: "Зарплата", nameEn: "Salary", kindRaw: "income", symbolName: "banknote", colorHex: "8E8E93", sortOrder: 8,
              keywords: ["зарплата", "salary", "зп", "оклад", "wage", "paycheck", "аванс"]),
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
