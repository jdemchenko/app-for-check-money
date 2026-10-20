import Foundation

enum CategoryMatcher {
    /// Scores categories by keyword hits; returns best match for optional preferred type.
    static func autoAssign(
        text: String,
        categories: [MoneyCategory],
        preferredType: TransactionType? = nil
    ) -> MoneyCategory? {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }

        var best: (category: MoneyCategory, score: Double)?

        for category in categories {
            if let preferredType,
               !category.kind.matches(preferredType) {
                continue
            }

            var score = 0.0
            for keyword in category.keywords {
                let k = TextNormalizer.normalize(keyword)
                guard !k.isEmpty else { continue }

                if normalized.contains(k) {
                    // Longer / multi-token keywords win ties
                    score += max(1.5, Double(k.count) / 2.5)
                    continue
                }

                // Light fuzzy: keyword tokens all present (order-independent)
                let tokens = k.split(separator: " ").map(String.init).filter { $0.count >= 2 }
                if tokens.count >= 2, tokens.allSatisfy({ normalized.contains($0) }) {
                    score += Double(tokens.count)
                }
            }

            // Also match localized category names
            for name in [category.nameRu, category.nameEn] {
                let n = TextNormalizer.normalize(name)
                if !n.isEmpty, normalized.contains(n) {
                    score += max(2.0, Double(n.count) / 2.0)
                }
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

enum TextNormalizer {
    /// Lowercase, ё→е, strip most punctuation, collapse whitespace.
    static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        s = s.replacingOccurrences(of: "ё", with: "е")
        s = s.replacingOccurrences(of: "Ё", with: "е")
        // Keep letters, digits, spaces
        s = s.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            // Treat punctuation as space so "АЗС," still yields "азс"
            return " "
        }.reduce(into: "") { $0.append($1) }
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
