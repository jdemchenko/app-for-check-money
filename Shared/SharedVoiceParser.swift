import Foundation

struct SharedVoiceDraft: Equatable {
    var amount: Double?
    var typeRaw: String?
    var categoryId: String?
    var note: String
    var rawText: String
    /// True when a category keyword actually matched (not a blind fallback).
    var categoryMatchedByKeyword: Bool
    /// Explicit foreign currency from speech (USD/EUR/…).
    /// `nil` when the user said «руб» / bare amount — use entry default (BYN).
    var currencyRaw: String?
    /// `weekly` / `monthly` when speech asked for a recurring rule; otherwise `nil`.
    var frequencyRaw: String?

    /// Happy-path autosave: amount + keyword category, not recurring.
    var isAutosaveReady: Bool {
        guard frequencyRaw == nil else { return false }
        guard let amount, amount > 0 else { return false }
        return categoryMatchedByKeyword && categoryId != nil
    }

    var isRecurring: Bool { frequencyRaw != nil }
}

enum SharedVoiceParser {
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

    /// Any currency *token* (amount unit or commodity mention).
    private static let currencyTokenPattern =
        #"(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?|dollars?|usd|eur|доллар(?:ов|а|ы)?|евро|₽|\$|€)"#

    /// Currency words stripped from notes only when they were the **amount unit**.
    private static let currencyWords = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + currencyTokenPattern + wa,
        options: []
    )

    /// Amount digit/decimal, optionally glued thousands with spaces.
    private static let amountNumberPattern = #"(\d+(?:\s+\d{3})*(?:[.,]\d{1,2})?)"#

    /// «покупка долларов», «купил доллары», «bought dollars» — commodity, not tx currency.
    private static let commodityCurrency = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:покупк[ауие]|купил[аи]?|bought|buying|purchase[sd]?|buy)"#
            + #"\s+"#
            + currencyTokenPattern
            + wa,
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

    /// Recurring cues — monthly first (longer phrases before shorter).
    private static let monthlyRecurring = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(every\s+month|each\s+month|monthly|per\s+month|раз\s+в\s+месяц|каждый\s+месяц|каждую\s+месяц|ежемесячно|раз\s+в\s+мес)"#
            + wa,
        options: []
    )
    private static let weeklyRecurring = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(every\s+week|each\s+week|weekly|per\s+week|раз\s+в\s+недел[юи]|каждую\s+неделю|каждый\s+недел[юи]|еженедельно)"#
            + wa,
        options: []
    )

    /// Split multi-expense utterances: «кофе 5 и такси 12», «coffee 5 and taxi 12».
    private static let multiSplit = try! NSRegularExpression(
        pattern: #"(?i)(?:,\s*|\s+и\s+|\s+and\s+)(?=(?:[^0-9]{0,40})?\d)"#,
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
        // Amount-unit руб only — keep «долларов» / «dollars» when they are what was bought.
        "рублей", "рубль", "рубля", "ruble", "rubles", "byn", "br",
        "копеек", "копейки", "копейка",
        "косметика", "cosmetics", "красота", "beauty",
        "категория", "category",
        "на", "за", "для", "и", "получил", "получила", "потратил", "потратила",
        "закинул", "закинула", "пополнил", "купил", "купила", "добавь", "кажется",
        "сегодня", "это", "будет", "свой", "свою",
        "got", "received", "spent", "paid", "bought",
        // NOTE: keep «аренда квартиры», «проезд», «телефон», «долларов» OUT — descriptions
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

    static func inferType(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if incomeCues.firstMatch(in: text, options: [], range: range) != nil {
            return "income"
        }
        if expenseCues.firstMatch(in: text, options: [], range: range) != nil {
            return "expense"
        }
        return nil
    }

    /// Currency for the **amount unit** wins.
    /// «900 рублей, покупка долларов» → `nil` (entry default BYN), not USD from trailing «долларов».
    /// «руб» / «рублей» near the amount → `nil` (never market RUB unless Settings entry is RUB).
    static func inferCurrency(from text: String) -> String? {
        if let attached = currencyAttachedToAmount(in: text) {
            return attached.currencyRaw
        }
        return looseForeignCurrency(in: text)
    }

    /// `nil` app currency means entry default; `found` distinguishes «руб» (resolved) from no unit.
    private struct AmountCurrencyResolve {
        /// `nil` = entry default (руб); non-nil = stamp USD/EUR/BYN.
        let currencyRaw: String?
    }

    /// Currency token glued to the numeric amount (before or after).
    private static func currencyAttachedToAmount(in text: String) -> AmountCurrencyResolve? {
        let patterns = [
            #"(?i)"# + amountNumberPattern + #"\s*"# + currencyTokenPattern,
            #"(?i)"# + currencyTokenPattern + #"\s*"# + amountNumberPattern,
        ]
        let nsRange = NSRange(text.startIndex..., in: text)
        var best: (location: Int, token: String)?
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            for match in re.matches(in: text, options: [], range: nsRange) {
                // Token is group 2 in amount→currency, group 1 in currency→amount.
                let tokenRange: NSRange
                if match.numberOfRanges >= 3 {
                    // Both patterns have 2 captures; detect which group is the currency token.
                    let g1 = Range(match.range(at: 1), in: text).map { String(text[$0]) } ?? ""
                    let g2 = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? ""
                    let token: String
                    if looksLikeCurrencyToken(g1) {
                        token = g1
                        tokenRange = match.range(at: 1)
                    } else {
                        token = g2
                        tokenRange = match.range(at: 2)
                    }
                    _ = tokenRange
                    let loc = match.range.location
                    if best == nil || loc < best!.location {
                        best = (loc, token)
                    }
                }
            }
        }
        // Spelled amount + unit: «тысяча … рублей» (no digits).
        if best == nil, let spelledToken = currencyAfterSpelledAmount(in: text) {
            return resolveCurrencyToken(spelledToken)
        }
        guard let token = best?.token else { return nil }
        return resolveCurrencyToken(token)
    }

    private static func currencyAfterSpelledAmount(in text: String) -> String? {
        // If AmountWords finds a spelled amount, take the first currency token after number-words start.
        guard AmountWords.parse(from: text) != nil else { return nil }
        // Prefer «… рублей/dollars» when digits are absent near the unit.
        let hasDigitAmount = text.range(of: #"\d"#, options: .regularExpression) != nil
        if hasDigitAmount { return nil }
        let re = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + currencyTokenPattern + wa,
            options: []
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range),
              let swift = Range(match.range, in: text)
        else { return nil }
        return String(text[swift])
    }

    private static func looksLikeCurrencyToken(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return false }
        if t.range(of: #"^\d"#, options: .regularExpression) != nil { return false }
        return true
    }

    private static func resolveCurrencyToken(_ raw: String) -> AmountCurrencyResolve {
        let t = TextNormalizer.normalize(raw)
            .replacingOccurrences(of: "$", with: "usd")
            .replacingOccurrences(of: "€", with: "eur")
            .replacingOccurrences(of: "₽", with: "rub")
        if t.contains("dollar") || t == "usd" || t.hasPrefix("доллар") {
            return AmountCurrencyResolve(currencyRaw: "usd")
        }
        if t.contains("euro") || t == "eur" || t.hasPrefix("евро") {
            return AmountCurrencyResolve(currencyRaw: "eur")
        }
        if t == "byn" || t == "br" || t.contains("бел") {
            return AmountCurrencyResolve(currencyRaw: "byn")
        }
        // «руб» / «рублей» / ruble → entry default (BYN), not market RUB
        return AmountCurrencyResolve(currencyRaw: nil)
    }

    /// Foreign currency mentioned when the amount had **no** unit — ignore commodity phrases.
    private static func looseForeignCurrency(in text: String) -> String? {
        var working = text
        let full = NSRange(working.startIndex..., in: working)
        working = commodityCurrency.stringByReplacingMatches(
            in: working,
            options: [],
            range: full,
            withTemplate: " "
        )
        let range = NSRange(working.startIndex..., in: working)
        let usd = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(dollars?|usd|доллар(?:ов|а|ы)?|\$)"# + wa,
            options: []
        )
        let eur = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(euros?|eur|евро|€)"# + wa,
            options: []
        )
        let byn = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(byn|br|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?)"# + wa,
            options: []
        )
        if usd.firstMatch(in: working, options: [], range: range) != nil { return "usd" }
        if eur.firstMatch(in: working, options: [], range: range) != nil { return "eur" }
        if byn.firstMatch(in: working, options: [], range: range) != nil { return "byn" }
        return nil
    }

    /// One utterance → one or more drafts. Recurring stays a single draft with `frequencyRaw`.
    static func parseMany(
        rawText: String,
        categories: [SharedCategoryDTO]
    ) -> [SharedVoiceDraft] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let frequency = detectFrequency(in: trimmed) {
            var draft = parse(rawText: stripRecurringCues(trimmed), categories: categories)
            draft.frequencyRaw = frequency
            draft.rawText = trimmed
            return [draft]
        }

        let segments = splitMultiExpense(trimmed)
        if segments.count >= 2 {
            let drafts = segments.compactMap { segment -> SharedVoiceDraft? in
                let d = parse(rawText: segment, categories: categories)
                guard let amount = d.amount, amount > 0 else { return nil }
                return d
            }
            if drafts.count >= 2 { return drafts }
        }

        return [parse(rawText: trimmed, categories: categories)]
    }

    static func parse(
        rawText: String,
        categories: [SharedCategoryDTO]
    ) -> SharedVoiceDraft {
        let frequency = detectFrequency(in: rawText)
        let working = frequency != nil ? stripRecurringCues(rawText) : rawText

        let amount = parseAmount(from: working)
        var type = inferType(from: working)
        let currency = inferCurrency(from: working)

        var matched = SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: type
        )
        if matched == nil {
            matched = SharedCategoryMatcher.autoAssign(
                text: working,
                categories: categories,
                preferredTypeRaw: nil
            )
        }

        if type == nil, let matched {
            type = matched.kindRaw == "both" ? "expense" : (
                matched.kindRaw == "income" ? "income" : "expense"
            )
        }
        if type == nil { type = "expense" }

        // Re-score with final type preference, then unrestricted fallback.
        matched = SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: type
        ) ?? SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: nil
        )

        let categoryMatchedByKeyword = matched != nil
        let categoryId = matched?.id
            ?? SharedCategoryMatcher.categories(forRaw: type!, in: categories).first?.id

        let note = extractNote(
            from: working,
            matchedCategory: matched,
            allCategories: categories
        )

        return SharedVoiceDraft(
            amount: amount,
            typeRaw: type,
            categoryId: categoryId,
            note: note,
            rawText: rawText,
            categoryMatchedByKeyword: categoryMatchedByKeyword,
            currencyRaw: currency,
            frequencyRaw: frequency
        )
    }

    // MARK: - Recurring / multi

    static func detectFrequency(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if monthlyRecurring.firstMatch(in: text, options: [], range: range) != nil {
            return "monthly"
        }
        if weeklyRecurring.firstMatch(in: text, options: [], range: range) != nil {
            return "weekly"
        }
        return nil
    }

    static func stripRecurringCues(_ text: String) -> String {
        var working = text
        let full = NSRange(working.startIndex..., in: working)
        working = monthlyRecurring.stringByReplacingMatches(
            in: working, options: [], range: full, withTemplate: " "
        )
        let full2 = NSRange(working.startIndex..., in: working)
        working = weeklyRecurring.stringByReplacingMatches(
            in: working, options: [], range: full2, withTemplate: " "
        )
        return working.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitMultiExpense(_ text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = multiSplit.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return [text] }

        var parts: [String] = []
        var start = text.startIndex
        for match in matches {
            guard let cut = Range(match.range, in: text) else { continue }
            let piece = String(text[start..<cut.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { parts.append(piece) }
            start = cut.upperBound
        }
        let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }

        // Keep only segments that still look like they carry an amount.
        let withAmount = parts.filter { parseAmount(from: $0) != nil }
        return withAmount.count >= 2 ? withAmount : [text]
    }

    // MARK: - Note extraction

    static func extractNote(
        from rawText: String,
        matchedCategory: SharedCategoryDTO?,
        allCategories: [SharedCategoryDTO]
    ) -> String {
        // 1) Explicit note command → trailing detail only
        if let commanded = noteFromCommand(in: rawText) {
            return finalizeNote(commanded, matchedCategory: matchedCategory)
        }

        // 2) Comma / dash tail: if prefix alone still matches same category, tail is the note
        if let (prefix, tail) = splitTrailingDetail(rawText),
           let matchedCategory {
            let prefixMatch = SharedCategoryMatcher.autoAssign(
                text: prefix,
                categories: allCategories,
                preferredTypeRaw: matchedCategory.kindRaw == "both" ? nil : (
                    matchedCategory.kindRaw == "income" ? "income" : "expense"
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

    private static func finalizeNote(_ text: String, matchedCategory: SharedCategoryDTO?) -> String {
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
        var working = text
        // Strip only the currency token attached to the amount (keep «долларов» in notes).
        let unitPatterns = [
            #"(?i)"# + amountNumberPattern + #"\s*"# + currencyTokenPattern,
            #"(?i)"# + currencyTokenPattern + #"\s*"# + amountNumberPattern,
        ]
        for pattern in unitPatterns {
            working = working.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        // Remaining bare digits (amount without a surviving unit token)
        working = working.replacingOccurrences(
            of: #"\d[\d\s.,]*"#,
            with: " ",
            options: .regularExpression
        )
        // Always drop lone «руб» leftovers; leave dollar/euro commodity words for the note.
        let rubOnly = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|₽)"# + wa,
            options: []
        )
        working = rubOnly.stringByReplacingMatches(
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
extension SharedVoiceParser {
    static func debugSelfCheck(categories: [SharedCategoryDTO]) -> [String] {
        var failures: [String] = []

        func check(
            _ label: String,
            _ raw: String,
            amount: Double,
            categoryId: String? = nil,
            note: String? = nil,
            currencyRaw: String? = nil,
            expectNilCurrency: Bool = false
        ) {
            let d = parse(rawText: raw, categories: categories)
            if d.amount != amount {
                failures.append("\(label) amount: got \(String(describing: d.amount)) expected \(amount)")
            }
            if let categoryId, d.categoryId != categoryId {
                failures.append("\(label) category: got \(String(describing: d.categoryId)) expected \(categoryId)")
            }
            if let note, TextNormalizer.normalize(d.note) != TextNormalizer.normalize(note) {
                failures.append("\(label) note: got «\(d.note)» expected «\(note)»")
            }
            if expectNilCurrency, d.currencyRaw != nil {
                failures.append("\(label) currency: got \(String(describing: d.currencyRaw)) expected nil")
            }
            if let currencyRaw, d.currencyRaw != currencyRaw {
                failures.append("\(label) currency: got \(String(describing: d.currencyRaw)) expected \(currencyRaw)")
            }
            let banned = ["рублей", "развлечения", "точка"]
            for b in banned where TextNormalizer.normalize(d.note).contains(TextNormalizer.normalize(b))
                && !(note.map { TextNormalizer.normalize($0).contains(TextNormalizer.normalize(b)) } ?? false) {
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
        check(
            "fx-rub-wins",
            "900 рублей, покупка долларов",
            amount: 900, note: "покупка долларов", expectNilCurrency: true
        )
        check(
            "hybrid-tyscha",
            "тыща 200 руб подарки деньги ульяне",
            amount: 1200, categoryId: "gifts", expectNilCurrency: true
        )
        check(
            "hybrid-two-thousand",
            "две тысячи 50 рублей",
            amount: 2050, expectNilCurrency: true
        )

        let multi = parseMany(rawText: "кофе 5 и такси 12", categories: categories)
        if multi.count != 2 {
            failures.append("multi count: got \(multi.count) expected 2")
        } else {
            if multi[0].amount != 5 { failures.append("multi[0] amount") }
            if multi[1].amount != 12 { failures.append("multi[1] amount") }
            if multi[0].categoryId != "food" { failures.append("multi[0] category food") }
            if multi[1].categoryId != "transport" { failures.append("multi[1] category transport") }
        }

        let recurring = parseMany(
            rawText: "Netflix 10 dollars every month",
            categories: categories
        )
        if recurring.count != 1 || recurring.first?.frequencyRaw != "monthly" {
            failures.append("recurring monthly: \(String(describing: recurring.first?.frequencyRaw))")
        }
        if recurring.first?.amount != 10 {
            failures.append("recurring amount")
        }

        let weekly = parse(
            rawText: "аренда 200 каждый месяц",
            categories: categories
        )
        if weekly.frequencyRaw != "monthly" {
            failures.append("ru recurring monthly")
        }

        return failures
    }
}
#endif
