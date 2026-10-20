import Foundation

struct VoiceDraft: Equatable {
    var amount: Double?
    var type: TransactionType?
    var categoryId: String?
    var note: String
    var rawText: String
}

enum VoiceParser {
    private static let expenseCues = try! NSRegularExpression(
        pattern: #"\b(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|расход)\b"#,
        options: [.caseInsensitive]
    )
    private static let incomeCues = try! NSRegularExpression(
        pattern: #"\b(got|received|earned|salary|income|получил|получила|зарплата|доход|заработал|заработала)\b"#,
        options: [.caseInsensitive]
    )

    static func parseAmount(from text: String) -> Double? {
        var cleaned = text
        // 80 000 → 80000
        cleaned = cleaned.replacingOccurrences(
            of: #"(\d)\s+(\d{3})\b"#,
            with: "$1$2",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")

        let pattern = #"(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|\$|usd|eur|€)?\s*(\d+(?:\.\d{1,2})?)"#
        if let match = firstCapture(pattern: pattern, in: cleaned),
           let value = Double(match),
           value > 0 {
            return (value * 100).rounded() / 100
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

    static func parse(
        rawText: String,
        categories: [MoneyCategory]
    ) -> VoiceDraft {
        let amount = parseAmount(from: rawText)
        var type = inferType(from: rawText)

        let matched = CategoryMatcher.autoAssign(
            text: rawText,
            categories: categories,
            preferredType: type
        )

        if type == nil, let matched {
            type = matched.kind == .both ? .expense : (
                matched.kind == .income ? .income : .expense
            )
        }
        if type == nil { type = .expense }

        let category = matched
            ?? CategoryMatcher.autoAssign(text: rawText, categories: categories, preferredType: type)
            ?? CategoryMatcher.categories(for: type!, in: categories).first

        let note = rawText
            .replacingOccurrences(of: #"\d[\d\s.,]*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VoiceDraft(
            amount: amount,
            type: type,
            categoryId: category?.id,
            note: note,
            rawText: rawText
        )
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
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
