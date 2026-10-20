import Foundation
import SwiftData

enum SeedData {
    static func ensureDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for (index, item) in defaults.enumerated() {
            context.insert(
                MoneyCategory(
                    id: item.id,
                    nameRu: item.nameRu,
                    nameEn: item.nameEn,
                    kind: item.kind,
                    keywords: item.keywords,
                    colorHex: item.colorHex,
                    symbolName: item.symbolName,
                    isDefault: true,
                    sortOrder: index
                )
            )
        }
        try? context.save()
    }

    static func restoreDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<MoneyCategory>()
        let all = (try? context.fetch(descriptor)) ?? []
        for cat in all where cat.isDefault {
            context.delete(cat)
        }
        for (index, item) in defaults.enumerated() {
            context.insert(
                MoneyCategory(
                    id: item.id,
                    nameRu: item.nameRu,
                    nameEn: item.nameEn,
                    kind: item.kind,
                    keywords: item.keywords,
                    colorHex: item.colorHex,
                    symbolName: item.symbolName,
                    isDefault: true,
                    sortOrder: index
                )
            )
        }
        try? context.save()
    }

    private struct DefaultCategory {
        let id: String
        let nameRu: String
        let nameEn: String
        let kind: CategoryKind
        let keywords: [String]
        let colorHex: String
        let symbolName: String
    }

    private static let defaults: [DefaultCategory] = [
        .init(
            id: "food",
            nameRu: "Еда",
            nameEn: "Food",
            kind: .expense,
            keywords: [
                "еда", "food", "кофе", "coffee", "обед", "lunch", "ужин", "dinner",
                "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe",
                "продукт", "grocery", "groceries", "пицца", "pizza", "бургер", "burger",
            ],
            colorHex: "FF9F0A",
            symbolName: "fork.knife"
        ),
        .init(
            id: "transport",
            nameRu: "Транспорт",
            nameEn: "Transport",
            kind: .expense,
            keywords: [
                "транспорт", "transport", "такси", "taxi", "метро", "metro",
                "автобус", "bus", "бензин", "gas", "fuel", "uber", "яндекс",
                "yandex", "парковка", "parking", "поезд", "train",
            ],
            colorHex: "64D2FF",
            symbolName: "car.fill"
        ),
        .init(
            id: "housing",
            nameRu: "Жильё",
            nameEn: "Housing",
            kind: .expense,
            keywords: [
                "жильё", "жилье", "housing", "аренда", "rent", "квартира",
                "apartment", "коммуналка", "utilities", "свет", "electricity",
                "вода", "water", "ипотека", "mortgage",
            ],
            colorHex: "AC8E68",
            symbolName: "house.fill"
        ),
        .init(
            id: "shopping",
            nameRu: "Покупки",
            nameEn: "Shopping",
            kind: .expense,
            keywords: [
                "покупки", "shopping", "одежда", "clothes", "магазин", "shop",
                "store", "amazon", "ozon", "wildberries", "wb",
            ],
            colorHex: "FF375F",
            symbolName: "bag.fill"
        ),
        .init(
            id: "health",
            nameRu: "Здоровье",
            nameEn: "Health",
            kind: .expense,
            keywords: [
                "здоровье", "health", "аптека", "pharmacy", "врач", "doctor",
                "медицина", "medicine", "спорт", "gym", "фитнес", "fitness",
            ],
            colorHex: "30D158",
            symbolName: "heart.fill"
        ),
        .init(
            id: "entertainment",
            nameRu: "Развлечения",
            nameEn: "Entertainment",
            kind: .expense,
            keywords: [
                "развлечения", "entertainment", "кино", "cinema", "movie",
                "игры", "games", "подписка", "subscription", "netflix",
                "spotify", "концерт", "concert",
            ],
            colorHex: "FF9F0A",
            symbolName: "film.fill"
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
                "зарплата", "salary", "зп", "оклад", "wage", "paycheck", "аванс",
            ],
            colorHex: "32D74B",
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
            colorHex: "0A84FF",
            symbolName: "laptopcomputer"
        ),
        .init(
            id: "gifts",
            nameRu: "Подарки",
            nameEn: "Gifts",
            kind: .both,
            keywords: [
                "подарок", "gift", "подарки", "gifts", "день рождения", "birthday",
            ],
            colorHex: "FF2D55",
            symbolName: "gift.fill"
        ),
        .init(
            id: "other-income",
            nameRu: "Прочий доход",
            nameEn: "Other income",
            kind: .income,
            keywords: [
                "доход", "income", "перевод", "transfer", "возврат", "refund",
            ],
            colorHex: "64D2FF",
            symbolName: "creditcard.fill"
        ),
    ]
}
