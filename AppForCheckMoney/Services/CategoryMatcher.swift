import Foundation

enum CategoryMatcher {
    /// Scores categories by keyword hits; returns best match for optional preferred type.
    static func autoAssign(
        text: String,
        categories: [MoneyCategory],
        preferredType: TransactionType? = nil
    ) -> MoneyCategory? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        var best: (category: MoneyCategory, score: Double)?

        for category in categories {
            if let preferredType,
               !category.kind.matches(preferredType) {
                continue
            }

            var score = 0.0
            for keyword in category.keywords {
                let k = keyword.lowercased()
                guard !k.isEmpty, normalized.contains(k) else { continue }
                score += max(1.0, Double(k.count) / 3.0)
            }

            if score > 0, best == nil || score > best!.score {
                best = (category, score)
            }
        }

        return best?.category
    }

    static func categories(
        for type: TransactionType,
        in categories: [MoneyCategory]
    ) -> [MoneyCategory] {
        categories
            .filter { $0.kind.matches(type) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
