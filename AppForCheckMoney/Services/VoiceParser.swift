import Foundation

struct VoiceDraft: Equatable {
    var amount: Double?
    var type: TransactionType?
    var categoryId: String?
    var note: String
    var rawText: String
    /// True when a category keyword actually matched (not a blind fallback).
    var categoryMatchedByKeyword: Bool
    /// Explicit foreign currency from speech (USD/EUR/…).
    /// `nil` when the user said «руб» / bare amount — use Settings **entry** currency (default BYN).
    var currency: AppCurrency?

    /// Happy-path autosave: amount + keyword category.
    var isAutosaveReady: Bool {
        guard let amount, amount > 0 else { return false }
        return categoryMatchedByKeyword && categoryId != nil
    }
}

enum VoiceParser {
    /// Unicode-safe token boundary (JS `\b` breaks on Cyrillic).
    private static let wb = #"(?<![0-9A-Za-zА-Яа-яЁё])"#
    private static let wa = #"(?![0-9A-Za-zА-Яа-яЁё])"#

    private static let expenseCues = try! NSRegularExpression(
        pattern: wb + #"(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|расход|закинул|закинула|пополнил|пополнила|добавь|добавьте|добавить|итого)"# + wa,
        options: [.caseInsensitive]
    )
    private static let incomeCues = try! NSRegularExpression(
        pattern: wb + #"(got|received|earned|salary|income|получил|получила|зарплат[аыуеой]|доход|заработал|заработала)"# + wa,
        options: [.caseInsensitive]
    )

    /// Currency *words* stripped from notes.
    /// «руб» / «рублей» → entry default (BYN), not RUB. Explicit dollar/euro/BYN set `VoiceDraft.currency`.
    private static let currencyWords = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?|dollars?|usd|eur|доллар(?:ов|а|ы)?|евро|₽|\$|€)"# + wa,
        options: []
    )

    private static let explicitUSD = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(dollars?|usd|доллар(?:ов|а|ы)?|\$)"# + wa,
        options: []
    )
    private static let explicitEUR = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(euros?|eur|евро|€)"# + wa,
        options: []
    )
    private static let explicitBYN = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(byn|br|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?)"# + wa,
        options: []
    )

    private static let leftoverPrepositions = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(на|за|для|про|из|от|по|и|a|an|the|for|on|at|to|of)"# + wa,
        options: []
    )

    private static let noteCommands: [String] = [
        #"(?i)в\s+скобочк(?:ах|и)\s+напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобках\s+напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобочк(?:ах|и)\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобках\s*[,:\-]?\s*(.+)$"#,
        #"(?i)(?:заметка|комментарий|note|comment)\s*[,:\-]?\s*(.+)$"#,
        #"(?i)напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)write\s+(?:down\s+)?(.+)$"#,
        #"(?i)in\s+parentheses\s*[,:\-]?\s*(.+)$"#,
    ]

    private static let fillerWords = try! NSRegularExpression(
        pattern: #"(?i)\b(пожалуйста|please|точка|point|ээ+|эм+|hmm+|uh+|um+)\b"#,
        options: []
    )

    /// Category-signal words that must never become a stored note by themselves.
    private static let noteSuppress: Set<String> = Set([
        // Food signals (not venue details)
        "еда", "food", "продукт", "продукты", "grocery", "groceries", "кофе",
        "coffee", "обед", "lunch", "ужин", "dinner", "завтрак", "breakfast",
        "пицца", "pizza", "бургер", "burger", "снек", "snack", "ресторан",
        "restaurant", "кафе", "cafe", "столовая", "супермаркет", "supermarket",
        // Transport / fuel signals
        "транспорт", "transport", "азс", "azs", "заправка", "бензин", "топливо",
        "gas", "fuel", "petrol", "diesel", "дизель", "gas station", "petrol station",
        "такси", "taxi", "метро", "metro", "subway", "автобус", "bus", "парковка",
        "parking", "station", "uber", "яндекс", "yandex", "поезд", "train",
        // Other category labels / signals
        // Category *labels* only — keep descriptive phrases (аренда квартиры, проезд…) as notes.
        "жильё", "жилье", "housing",
        "еда", "food", "продукты",
        "транспорт", "transport",
        "здоровье", "health",
        "одежда", "clothing", "clothes",
        "развлечения", "entertainment",
        "связь", "техника",
        "накопления", "savings",
        "другое", "other", "разное", "misc",
        "зарплата", "зарплату", "зарплаты", "salary", "зп", "оклад", "wage",
        "paycheck", "аванс",
        "фриланс", "freelance",
        "подарок", "подарки", "gift", "gifts",
        "доход", "income", "перевод", "transfer", "возврат", "refund",
        "рублей", "рубль", "рубля", "ruble", "rubles", "byn", "br",
        "dollar", "dollars", "usd", "eur", "euro", "копеек", "копейки", "копейка",
        "косметика", "cosmetics", "красота", "beauty",
        "категория", "category",
        "на", "за", "для", "и", "получил", "получила", "потратил", "потратила",
        "закинул", "закинула", "пополнил", "купил", "купила", "добавь", "кажется",
        "сегодня", "это", "будет", "свой", "свою",
        "got", "received", "spent", "paid", "bought",
        // NOTE: keep «аренда квартиры», «проезд», «телефон» OUT — those are descriptions
    ].map { TextNormalizer.normalize($0) })

    static func parseAmount(from text: String) -> Double? {
        if let fromWords = AmountWords.parse(from: text) {
            return fromWords
        }
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(
            of: #"(\d)\s+(\d{3})\b"#,
            with: "$1$2",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")

        let patterns = [
            #"(?i)(\d+(?:[.,]\d{1,2})?)\s*(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|\$|usd|eur|€)"#,
            #"(?i)(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|\$|usd|eur|€)\s*(\d+(?:[.,]\d{1,2})?)"#,
            #"(\d+(?:[.,]\d{1,2})?)"#,
        ]
        for pattern in patterns {
            if let match = firstCapture(pattern: pattern, in: cleaned) {
                let normalized = match.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value > 0 {
                    return (value * 100).rounded() / 100
                }
            }
        }
        return nil
    }

    static func inferType(from text: String) -> TransactionType? {
        let range = NSRange(text.startIndex..., in: text)
        if incomeCues.firstMatch(in: text, options: [], range: range) != nil {
            return .income
        }
        if expenseCues.firstMatch(in: text, options: [], range: range) != nil {
            return .expense
        }
        return nil
    }

    /// Detects an **explicit** foreign currency. «руб» returns `nil` → stamp entry default (BYN).
    static func inferCurrency(from text: String) -> AppCurrency? {
        let range = NSRange(text.startIndex..., in: text)
        if explicitUSD.firstMatch(in: text, options: [], range: range) != nil { return .usd }
        if explicitEUR.firstMatch(in: text, options: [], range: range) != nil { return .eur }
        if explicitBYN.firstMatch(in: text, options: [], range: range) != nil { return .byn }
        return nil
    }

    static func parse(
        rawText: String,
        categories: [MoneyCategory]
    ) -> VoiceDraft {
        let amount = parseAmount(from: rawText)
        var type = inferType(from: rawText)
        let currency = inferCurrency(from: rawText)

        var matched = CategoryMatcher.autoAssign(
            text: rawText,
            categories: categories,
            preferredType: type
        )
        if matched == nil {
            matched = CategoryMatcher.autoAssign(
                text: rawText,
                categories: categories,
                preferredType: nil
            )
        }

        if type == nil, let matched {
            type = matched.kind == .both ? .expense : (
                matched.kind == .income ? .income : .expense
            )
        }
        if type == nil { type = .expense }

        // Re-score with final type preference, then unrestricted fallback.
        matched = CategoryMatcher.autoAssign(
            text: rawText,
            categories: categories,
            preferredType: type
        ) ?? CategoryMatcher.autoAssign(
            text: rawText,
            categories: categories,
            preferredType: nil
        )

        let categoryMatchedByKeyword = matched != nil
        let categoryId = matched?.id
            ?? CategoryMatcher.categories(for: type!, in: categories).first?.id

        let note = extractNote(
            from: rawText,
            matchedCategory: matched,
            allCategories: categories
        )

        return VoiceDraft(
            amount: amount,
            type: type,
            categoryId: categoryId,
            note: note,
            rawText: rawText,
            categoryMatchedByKeyword: categoryMatchedByKeyword,
            currency: currency
        )
    }

    // MARK: - Note extraction

    static func extractNote(
        from rawText: String,
        matchedCategory: MoneyCategory?,
        allCategories: [MoneyCategory]
    ) -> String {
        // 1) Explicit note command → trailing detail only
        if let commanded = noteFromCommand(in: rawText) {
            return finalizeNote(commanded, matchedCategory: matchedCategory)
        }

        // 2) Comma / dash tail: if prefix alone still matches same category, tail is the note
        if let (prefix, tail) = splitTrailingDetail(rawText),
           let matchedCategory {
            let prefixMatch = CategoryMatcher.autoAssign(
                text: prefix,
                categories: allCategories,
                preferredType: matchedCategory.kind == .both ? nil : (
                    matchedCategory.kind == .income ? .income : .expense
                )
            )
            if prefixMatch?.id == matchedCategory.id {
                return finalizeNote(tail, matchedCategory: matchedCategory)
            }
        }

        // 3) Remainder after stripping amount / currency / cues / names / suppress signals
        var working = rawText
        for pattern in noteCommands {
            working = working.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        working = stripAmountsAndCurrency(working)
        working = stripCues(working)
        if let matchedCategory {
            working = stripKeyword(matchedCategory.nameRu, from: working)
            working = stripKeyword(matchedCategory.nameEn, from: working)
        }
        working = stripSuppressTokens(working)
        working = stripFiller(working)
        return finalizeNote(working, matchedCategory: matchedCategory)
    }

    private static func noteFromCommand(in text: String) -> String? {
        for pattern in noteCommands {
            if let capture = firstCapture(pattern: pattern, in: text) {
                let cleaned = cleanNoteFragment(capture)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func splitTrailingDetail(_ text: String) -> (prefix: String, tail: String)? {
        let separators = [",", " — ", " – ", " - "]
        var best: (prefix: String, tail: String)?
        for sep in separators {
            guard let range = text.range(of: sep, options: .backwards) else { continue }
            let prefix = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty, !tail.isEmpty else { continue }
            // Prefer the rightmost short-ish separator split
            best = (prefix, tail)
            break
        }
        return best
    }

    private static func finalizeNote(_ text: String, matchedCategory: MoneyCategory?) -> String {
        var s = stripAmountsAndCurrency(text)
        s = stripCues(s)
        s = stripFiller(s)
        if let matchedCategory {
            s = stripKeyword(matchedCategory.nameRu, from: s)
            s = stripKeyword(matchedCategory.nameEn, from: s)
            for keyword in matchedCategory.keywords.sorted(by: { $0.count > $1.count }) {
                // Keep detail-like keywords (кинотеатр) unless they're in noteSuppress
                let norm = TextNormalizer.normalize(keyword)
                if noteSuppress.contains(norm) {
                    s = stripKeyword(keyword, from: s)
                }
            }
        }
        s = leftoverPrepositions.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " "
        )
        s = stripSuppressTokens(s)
        s = cleanNoteFragment(s)
        let normalized = TextNormalizer.normalize(s)
        if normalized.isEmpty { return "" }
        // Drop pure category-signal notes («заправка», «АЗС», «food»)
        if noteSuppress.contains(normalized) { return "" }
        let tokens = normalized.split(separator: " ").map(String.init)
        if !tokens.isEmpty, tokens.allSatisfy({ noteSuppress.contains($0) }) {
            return ""
        }
        return s
    }

    private static func stripAmountsAndCurrency(_ text: String) -> String {
        var working = text.replacingOccurrences(
            of: #"\d[\d\s.,]*"#,
            with: " ",
            options: .regularExpression
        )
        working = currencyWords.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(working.startIndex..., in: working),
            withTemplate: " "
        )
        working = AmountWords.stripSpelled(from: working)
        return working
    }

    private static func stripCues(_ text: String) -> String {
        var working = expenseCues.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
        working = incomeCues.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(working.startIndex..., in: working),
            withTemplate: " "
        )
        return working
    }

    private static func stripFiller(_ text: String) -> String {
        fillerWords.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
    }

    private static func stripSuppressTokens(_ text: String) -> String {
        var working = text
        for token in noteSuppress.sorted(by: { $0.count > $1.count }) {
            working = stripKeyword(token, from: working)
        }
        return working
    }

    private static func stripKeyword(_ keyword: String, from text: String) -> String {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return text }
        let escaped = NSRegularExpression.escapedPattern(for: k)
        let flexible = escaped.replacingOccurrences(of: #"\s+"#, with: #"\s+"#, options: .regularExpression)
        let pattern = #"(?i)(?<![0-9A-Za-zА-Яа-яЁё])\#(flexible)(?![0-9A-Za-zА-Яа-яЁё])"#
        return text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    private static func cleanNoteFragment(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: #"[«»\"“”]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^[,\.\!\?;:\-\s]+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[,.\s]+$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count <= 1, s.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) }) {
            return ""
        }
        return s
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[swiftRange])
    }
}

#if DEBUG
extension VoiceParser {
    static func debugSelfCheck(categories: [MoneyCategory]) -> [String] {
        var failures: [String] = []

        func check(_ label: String, _ raw: String, amount: Double, categoryId: String, note: String) {
            let d = parse(rawText: raw, categories: categories)
            if d.amount != amount {
                failures.append("\(label) amount: got \(String(describing: d.amount)) expected \(amount)")
            }
            if d.categoryId != categoryId {
                failures.append("\(label) category: got \(String(describing: d.categoryId)) expected \(categoryId)")
            }
            if TextNormalizer.normalize(d.note) != TextNormalizer.normalize(note) {
                failures.append("\(label) note: got «\(d.note)» expected «\(note)»")
            }
            let banned = ["рублей", "dollars", "развлечения", "точка"]
            for b in banned where TextNormalizer.normalize(d.note).contains(TextNormalizer.normalize(b))
                && TextNormalizer.normalize(note) != TextNormalizer.normalize(b) {
                failures.append("\(label) note contains filler «\(b)»")
            }
        }

        check(
            "ru-ent-cmd",
            "150 рублей развлечения, в скобочках напиши кинотеатр",
            amount: 150, categoryId: "entertainment", note: "кинотеатр"
        )
        check(
            "ru-ent-short",
            "150 рублей развлечения, кинотеатр",
            amount: 150, categoryId: "entertainment", note: "кинотеатр"
        )
        check(
            "en-food",
            "20 dollars food",
            amount: 20, categoryId: "food", note: ""
        )
        check(
            "ru-gas",
            "200 рублей АЗС, заправка",
            amount: 200, categoryId: "transport", note: ""
        )
        check(
            "en-gas",
            "200 dollars gas station",
            amount: 200, categoryId: "transport", note: ""
        )
        // DeepSeek free-form patterns
        check(
            "ds-phone",
            "20 рублей закинул на свой телефон",
            amount: 20, categoryId: "telecom", note: "телефон"
        )
        check(
            "ds-fare",
            "70 рублей это будет проезд на автобусе",
            amount: 70, categoryId: "transport", note: "проезд автобусе"
        )
        check(
            "ds-rent",
            "добавь тысяча тридцать пять рублей. Аренда квартиры.",
            amount: 1035, categoryId: "housing", note: "Аренда квартиры"
        )
        check(
            "ds-kopeks",
            "купил картошки гарнир огурцов итого 7 рублей 40 копеек",
            amount: 7.4, categoryId: "food", note: "картошки гарнир огурцов"
        )

        return failures
    }
}
#endif
