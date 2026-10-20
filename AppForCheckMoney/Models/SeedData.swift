import Foundation
import SwiftData

enum SeedData {
    static func ensureDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            for (index, item) in defaults.enumerated() {
                context.insert(makeCategory(from: item, sortOrder: index))
            }
            try? context.save()
            return
        }
        refreshDefaultKeywords(in: context)
    }

    /// Updates keywords / names / symbols for seeded defaults without wiping custom categories.
    static func refreshDefaultKeywords(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for (index, item) in defaults.enumerated() {
            if let cat = byId[item.id] {
                cat.nameRu = item.nameRu
                cat.nameEn = item.nameEn
                cat.kind = item.kind
                cat.keywords = item.keywords
                cat.colorHex = item.colorHex
                cat.symbolName = item.symbolName
                cat.isDefault = true
                cat.sortOrder = index
            } else {
                let created = makeCategory(from: item, sortOrder: index)
                context.insert(created)
                byId[item.id] = created
            }
        }
        try? context.save()
    }

    static func restoreDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let all = (try? context.fetch(descriptor)) ?? []
        let keepIds = Set(defaults.map(\.id))
        for cat in all where cat.isDefault {
            context.delete(cat)
        }
        // Drop orphaned defaults no longer in the DeepSeek-aligned set (e.g. old shopping-only installs keep id).
        _ = keepIds
        for (index, item) in defaults.enumerated() {
            context.insert(makeCategory(from: item, sortOrder: index))
        }
        try? context.save()
    }

    private static func makeCategory(from item: DefaultCategory, sortOrder: Int) -> MoneyCategory {
        MoneyCategory(
            id: item.id,
            nameRu: item.nameRu,
            nameEn: item.nameEn,
            kind: item.kind,
            keywords: item.keywords,
            colorHex: item.colorHex,
            symbolName: item.symbolName,
            isDefault: true,
            sortOrder: sortOrder
        )
    }

    /// Synonym bank used for seeding defaults and for manual-category keyword suggestions.
    struct SynonymBank: Sendable {
        let id: String
        let nameRu: String
        let nameEn: String
        let kind: CategoryKind
        let keywords: [String]
        let colorHex: String
        let symbolName: String
    }

    static var synonymBanks: [SynonymBank] { defaults }

    private typealias DefaultCategory = SynonymBank

    /// DeepSeek-aligned expense grid (+ Beauty) and income helpers.
    /// Keyword lists mirrored by `scripts/voice-selftest.mjs`.
    private static let defaults: [DefaultCategory] = [
        .init(
            id: "housing",
            nameRu: "Жильё",
            nameEn: "Housing",
            kind: .expense,
            keywords: [
                "жильё", "жилье", "housing", "аренда", "rent", "квартира",
                "apartment", "коммуналка", "utilities", "свет", "electricity",
                "вода", "water", "ипотека", "mortgage", "жкх", "газ",
                "интернет дома", "квартплата",
            ],
            colorHex: "8E8E93",
            symbolName: "house.fill"
        ),
        .init(
            id: "food",
            nameRu: "Еда",
            nameEn: "Food",
            kind: .expense,
            keywords: [
                "еда", "food", "кофе", "coffee", "обед", "lunch", "ужин", "dinner",
                "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe",
                "продукт", "продукты", "grocery", "groceries", "пицца", "pizza",
                "бургер", "burger", "снек", "snack", "столовая", "супермаркет",
                "supermarket", "макдональдс", "mcdonalds", "картошк", "огурц",
                "гарнир", "доставка еды", "пятёрочка", "пятерочка",
            ],
            colorHex: "8E8E93",
            symbolName: "fork.knife"
        ),
        .init(
            id: "transport",
            nameRu: "Транспорт",
            nameEn: "Transport",
            kind: .expense,
            keywords: [
                "транспорт", "transport", "такси", "taxi", "метро", "metro", "subway",
                "автобус", "bus", "бензин", "gas", "fuel", "топливо", "заправка",
                "азс", "azs", "gas station", "petrol", "diesel", "дизель",
                "uber", "яндекс", "yandex", "парковка", "parking", "поезд", "train",
                "трамвай", "tram", "самокат", "scooter", "каршеринг", "carshare",
                "проезд", "fare",
            ],
            colorHex: "8E8E93",
            symbolName: "car.fill"
        ),
        .init(
            id: "health",
            nameRu: "Здоровье",
            nameEn: "Health",
            kind: .expense,
            keywords: [
                "здоровье", "health", "аптека", "pharmacy", "врач", "doctor",
                "медицина", "medicine", "спорт", "gym", "фитнес", "fitness",
                "таблетки", "больница", "hospital", "стоматолог", "dentist",
            ],
            colorHex: "8E8E93",
            symbolName: "heart.fill"
        ),
        // Kept id `shopping` so existing installs refresh in place → Одежда.
        .init(
            id: "shopping",
            nameRu: "Одежда",
            nameEn: "Clothing",
            kind: .expense,
            keywords: [
                "одежда", "clothing", "clothes", "обувь", "shoes", "куртка",
                "джинсы", "магазин одежды", "wildberries", "wb", "ozon",
                "вещи", "покупки одежды", "шопинг",
            ],
            colorHex: "8E8E93",
            symbolName: "tshirt.fill"
        ),
        .init(
            id: "entertainment",
            nameRu: "Развлечения",
            nameEn: "Entertainment",
            kind: .expense,
            keywords: [
                "развлечения", "entertainment", "кино", "кинотеатр", "cinema",
                "movie", "movies", "театр", "theater", "theatre", "игры", "games",
                "подписка", "subscription", "netflix", "spotify", "концерт",
                "concert", "клуб", "club", "бар", "bar", "bowling", "хобби",
            ],
            colorHex: "8E8E93",
            symbolName: "film.fill"
        ),
        .init(
            id: "telecom",
            nameRu: "Связь и техника",
            nameEn: "Tech & Comms",
            kind: .expense,
            keywords: [
                "связь", "телефон", "phone", "мобильн", "mobile", "тариф",
                "интернет", "wifi", "роутер", "техника", "гаджет", "gadget",
                "закинул на телефон", "пополнил телефон", "sim", "сим",
                "apple", "samsung", "ноутбук", "laptop", "наушники",
            ],
            colorHex: "8E8E93",
            symbolName: "iphone"
        ),
        .init(
            id: "beauty",
            nameRu: "Красота",
            nameEn: "Beauty",
            kind: .expense,
            keywords: [
                "красота", "beauty", "косметика", "cosmetics", "макияж", "makeup",
                "помада", "lipstick", "крем", "cream", "шампунь", "shampoo",
                "маникюр", "manicure", "педикюр", "pedicure", "салон", "salon",
                "парикмахер", "hairdresser", "стрижка", "haircut", "парфюм",
                "perfume", "духи", "ногти", "nails", "spa",
            ],
            colorHex: "AEAEB2",
            symbolName: "sparkles"
        ),
        .init(
            id: "gifts",
            nameRu: "Подарки",
            nameEn: "Gifts",
            kind: .both,
            keywords: [
                "подарок", "gift", "подарки", "gifts", "день рождения", "birthday",
            ],
            colorHex: "8E8E93",
            symbolName: "gift.fill"
        ),
        .init(
            id: "savings",
            nameRu: "Накопления",
            nameEn: "Savings",
            kind: .expense,
            keywords: [
                "накопления", "savings", "отложил", "отложить", "копилк",
                "вклад", "deposit", "кредит", "credit", "ипотечный платёж",
                "долг", "debt",
            ],
            colorHex: "8E8E93",
            symbolName: "banknote.fill"
        ),
        .init(
            id: "other-expense",
            nameRu: "Другое",
            nameEn: "Other",
            kind: .expense,
            keywords: ["другое", "other", "разное", "misc"],
            colorHex: "8E8E93",
            symbolName: "circle.fill"
        ),
        .init(
            id: "salary",
            nameRu: "Зарплата",
            nameEn: "Salary",
            kind: .income,
            keywords: [
                "зарплата", "зарплату", "зарплаты", "зарплатой", "salary", "зп",
                "оклад", "wage", "paycheck", "аванс", "payroll",
            ],
            colorHex: "8E8E93",
            symbolName: "briefcase.fill"
        ),
        .init(
            id: "freelance",
            nameRu: "Фриланс",
            nameEn: "Freelance",
            kind: .income,
            keywords: [
                "фриланс", "freelance", "проект", "project", "клиент", "client",
                "заказ", "contract",
            ],
            colorHex: "8E8E93",
            symbolName: "laptopcomputer"
        ),
        .init(
            id: "other-income",
            nameRu: "Прочий доход",
            nameEn: "Other income",
            kind: .income,
            keywords: [
                "доход", "income", "перевод", "transfer", "возврат", "refund",
            ],
            colorHex: "8E8E93",
            symbolName: "creditcard.fill"
        ),
    ]
}
