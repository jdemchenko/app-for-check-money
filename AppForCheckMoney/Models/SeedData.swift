import Foundation
import SwiftData

enum SeedData {
    /// Fallback when a user-created category is deleted (expense txs).
    static let otherExpenseId = "other-expense"
    /// Fallback when a user-created category is deleted (income txs).
    static let otherIncomeId = "other-income"

    /// Deletes a **user-created** category (`isDefault == false`).
    /// Built-in seed categories are rejected (returns `nil`).
    /// Transactions that used the category are reassigned to «Другое» / Other
    /// (`other-expense`) or «Прочий доход» / Other income (`other-income`) by type.
    /// - Returns: number of transactions reassigned, or `nil` if delete was refused.
    @discardableResult
    static func deleteUserCategory(_ category: MoneyCategory, in context: ModelContext) -> Int? {
        guard !category.isDefault else { return nil }
        ensureDefaults(in: context)

        let catId = category.id
        let descriptor = FetchDescriptor<MoneyTransaction>(
            predicate: #Predicate<MoneyTransaction> { $0.categoryId == catId }
        )
        let txs = (try? context.fetch(descriptor)) ?? []
        for tx in txs {
            tx.categoryId = tx.type == .income ? otherIncomeId : otherExpenseId
        }
        context.delete(category)
        try? context.save()
        return txs.count
    }

    static func transactionCount(forCategoryId categoryId: String, in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<MoneyTransaction>(
            predicate: #Predicate<MoneyTransaction> { $0.categoryId == categoryId }
        )
        return (try? context.fetch(descriptor))?.count ?? 0
    }

    static func ensureDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            for (index, item) in defaults.enumerated() {
                context.insert(makeCategory(from: item, sortOrder: index))
            }
        } else {
            refreshDefaultKeywords(in: context)
        }
        ensureLedgerDefaults(in: context)
        try? context.save()
    }

    /// Private space + default BYN cash account (idempotent).
    static func ensureLedgerDefaults(in context: ModelContext) {
        let spaces = (try? context.fetch(FetchDescriptor<MoneySpace>())) ?? []
        if spaces.first(where: { $0.id == SpaceIDs.privateDefault }) == nil {
            context.insert(MoneySpace(
                id: SpaceIDs.privateDefault,
                name: L10n.string("space.privateDefaultName"),
                kind: .privateSpace
            ))
        }

        let accounts = (try? context.fetch(FetchDescriptor<MoneyAccount>())) ?? []
        if accounts.first(where: { $0.id == AccountIDs.cashBYN }) == nil {
            context.insert(MoneyAccount(
                id: AccountIDs.cashBYN,
                name: L10n.string("account.cashBYN"),
                currency: .byn,
                spaceId: SpaceIDs.privateDefault,
                sortOrder: 0,
                symbolName: "banknote"
            ))
        }

        // Stamp legacy txs missing accountId onto default cash.
        let txs = (try? context.fetch(FetchDescriptor<MoneyTransaction>())) ?? []
        for tx in txs where tx.accountId.isEmpty {
            tx.accountId = AccountIDs.cashBYN
            if tx.spaceId.isEmpty { tx.spaceId = SpaceIDs.privateDefault }
        }
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
                "еда", "еды", "еду", "едой", "food",
                "кофе", "coffee", "кофейн", "кофейня", "кофейню",
                "обед", "lunch", "ужин", "dinner",
                "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe",
                "продукт", "продукты", "grocery", "groceries", "пицца", "pizza",
                "бургер", "burger", "снек", "snack", "столовая", "супермаркет",
                "supermarket", "макдональдс", "mcdonalds", "картошк", "огурц",
                "гарнир", "доставка еды", "доставку еды", "доставка", "доставку",
                "доставк", "delivery", "food delivery", "food order", "заказ еды",
                "поесть", "поел", "поела", "пообедал", "пообедала", "поужинал", "поужинала",
                "пятёрочка", "пятерочка",
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
                "заправил", "заправила", "заправ", "машину", "машина",
                "азс", "azs", "gas station", "petrol", "diesel", "дизель",
                "uber", "яндекс такси", "яндекс го", "yandex go", "yandex taxi",
                "парковка", "parking", "поезд", "train",
                "трамвай", "tram", "самокат", "scooter", "каршеринг", "carshare", "carsharing",
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
                "концерт", "concert", "клуб", "club", "бар", "bar", "bowling", "хобби",
            ],
            colorHex: "8E8E93",
            symbolName: "film.fill"
        ),
        .init(
            id: "subscriptions",
            nameRu: "Подписки",
            nameEn: "Subscriptions",
            kind: .expense,
            keywords: [
                "подписк", "подписка", "подписку", "подписки", "subscription", "subscriptions",
                "программа", "программу", "программе",
                "netflix", "spotify",
                "яндекс music", "yandex music", "яндекс музык", "яндекс plus", "яндекс плюс",
                "yandex plus", "apple music", "apple",
                "эпл мьюзик", "эппл мьюзик", "эпл music",
                "youtube premium", "youtube music", "ютюб премиум", "ютуб премиум",
            ],
            colorHex: "8E8E93",
            symbolName: "rectangle.stack.fill.badge.plus"
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
            keywords: [
                "другое", "other", "разное", "misc",
                "игрушк", "toys", "toy", "цвет", "flowers", "flower",
            ],
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
                "заказчик", "contract",
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
