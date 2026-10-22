import Foundation

/// Suggests SF Symbol names from a category title (and SeedData family matches).
enum SymbolSuggester {
    private static let tokenMap: [(tokens: [String], symbols: [String])] = [
        (["еда", "food", "кофе", "cafe", "обед", "ресторан", "pizza"],
         ["fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill"]),
        (["транспорт", "transport", "такси", "taxi", "метро", "bus", "авто", "car"],
         ["car.fill", "bus.fill", "tram.fill", "fuelpump.fill"]),
        (["жиль", "housing", "аренда", "rent", "квартир", "house"],
         ["house.fill", "building.2.fill", "key.fill"]),
        (["покуп", "shop", "одежд", "clothes", "магазин", "bag"],
         ["bag.fill", "cart.fill", "tshirt.fill"]),
        (["здоров", "health", "аптек", "врач", "doctor", "fitness", "спорт"],
         ["heart.fill", "cross.case.fill", "figure.run"]),
        (["развлеч", "entertainment", "кино", "movie", "игр", "game", "music"],
         ["film.fill", "ticket.fill", "gamecontroller.fill", "music.note"]),
        (["космет", "beauty", "makeup", "маникюр", "салон", "парфюм", "cream"],
         ["mouth.fill", "comb.fill", "sparkles", "drop.fill"]),
        (["зарплат", "salary", "оклад", "wage", "payroll"],
         ["briefcase.fill", "banknote.fill", "dollarsign.circle.fill"]),
        (["фриланс", "freelance", "проект", "client"],
         ["laptopcomputer", "desktopcomputer", "hammer.fill"]),
        (["подарок", "gift", "birthday"],
         ["gift.fill", "birthday.cake.fill"]),
        (["доход", "income", "перевод", "refund"],
         ["creditcard.fill", "arrow.down.circle.fill"]),
        (["питом", "pet", "собак", "кошк", "dog", "cat"],
         ["pawprint.fill", "cat.fill", "dog.fill"]),
        (["дет", "child", "kids", "школ", "school"],
         ["figure.and.child.holdinghands", "book.fill"]),
        (["путеше", "travel", "отпуск", "flight", "отель"],
         ["airplane", "suitcase.fill", "bed.double.fill"]),
        (["связь", "phone", "internet", "mobile", "wifi", "телефон", "техник", "гаджет", "iphone"],
         ["iphone", "phone.fill", "wifi", "antenna.radiowaves.left.and.right"]),
        (["накоплен", "savings", "вклад", "копилк", "кредит", "debt"],
         ["banknote.fill", "chart.line.uptrend.xyaxis", "safe.fill"]),
    ]

    static func suggest(nameRu: String, nameEn: String = "") -> [String] {
        let blob = TextNormalizer.normalize([nameRu, nameEn].filter { !$0.isEmpty }.joined(separator: " "))
        guard !blob.isEmpty else {
            return ["circle.fill", "tag.fill", "star.fill"]
        }

        var ranked: [(symbol: String, score: Int)] = []

        // Family bank symbol first when name matches a SeedData category.
        if let family = KeywordSuggester.matchedFamily(nameRu: nameRu, nameEn: nameEn) {
            ranked.append((family.symbolName, 100))
        }

        for entry in tokenMap {
            var hit = 0
            for token in entry.tokens where blob.contains(token) || token.contains(blob) {
                hit += token.count >= 4 ? 3 : 2
            }
            guard hit > 0 else { continue }
            for (i, symbol) in entry.symbols.enumerated() {
                ranked.append((symbol, hit * 10 - i))
            }
        }

        if ranked.isEmpty {
            ranked = [
                ("circle.fill", 1),
                ("tag.fill", 1),
                ("folder.fill", 1),
                ("star.fill", 1),
            ]
        }

        var seen = Set<String>()
        var out: [String] = []
        for item in ranked.sorted(by: { $0.score > $1.score }) {
            guard seen.insert(item.symbol).inserted else { continue }
            out.append(item.symbol)
            if out.count >= 8 { break }
        }
        return out
    }
}
