import Foundation

enum SharedCategoryMatcher {
    /// Scores categories by keyword hits; returns best match for optional preferred type.
    static func autoAssign(
        text: String,
        categories: [SharedCategoryDTO],
        preferredTypeRaw: String? = nil
    ) -> SharedCategoryDTO? {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }

        var best: (category: SharedCategoryDTO, score: Double)?

        for category in categories {
            if let preferredTypeRaw,
               !category.matchesType(preferredTypeRaw) {
                continue
            }

            var score = 0.0
            for keyword in category.keywords {
                let k = TextNormalizer.normalize(keyword)
                guard !k.isEmpty else { continue }

                if normalized.contains(k) {
                    score += max(1.5, Double(k.count) / 2.5)
                    continue
                }

                let tokens = k.split(separator: " ").map(String.init).filter { $0.count >= 2 }
                if tokens.count >= 2, tokens.allSatisfy({ normalized.contains($0) }) {
                    score += Double(tokens.count)
                }
            }

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
        forRaw typeRaw: String,
        in categories: [SharedCategoryDTO]
    ) -> [SharedCategoryDTO] {
        categories
            .filter { $0.matchesType(typeRaw) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension SharedCategoryDTO {
    func matchesType(_ typeRaw: String) -> Bool {
        switch kindRaw {
        case "both": return true
        case "expense": return typeRaw == "expense"
        case "income": return typeRaw == "income"
        default: return typeRaw == "expense"
        }
    }
}
