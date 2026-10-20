import Foundation

/// Proposes marker keywords when the user creates/edits a category by name.
/// Matches SeedData synonym banks (RU+EN); falls back to name-derived starters.
enum KeywordSuggester {
    /// Minimum family score before adopting that bank's full keyword list.
    private static let familyThreshold = 4.0

    static func suggest(
        nameRu: String,
        nameEn: String = "",
        symbolName: String = "",
        kind: CategoryKind? = nil
    ) -> [String] {
        let ru = nameRu.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ru.isEmpty || !en.isEmpty else { return [] }

        var result: [String] = []
        result.append(contentsOf: derivedFromNames(ru: ru, en: en))

        if let family = bestFamily(
            nameRu: ru,
            nameEn: en,
            symbolName: symbolName,
            kind: kind
        ) {
            result.append(contentsOf: family.keywords)
        } else {
            result.append(contentsOf: nearbySynonyms(from: [ru, en]))
        }

        return dedupe(result)
    }

    /// Comma-separated form used by the category editor field.
    static func suggestCSV(
        nameRu: String,
        nameEn: String = "",
        symbolName: String = "",
        kind: CategoryKind? = nil
    ) -> String {
        suggest(nameRu: nameRu, nameEn: nameEn, symbolName: symbolName, kind: kind)
            .joined(separator: ", ")
    }

    // MARK: - Family match

    private static func bestFamily(
        nameRu: String,
        nameEn: String,
        symbolName: String,
        kind: CategoryKind?
    ) -> SeedData.SynonymBank? {
        let queries = [nameRu, nameEn]
            .map(TextNormalizer.normalize)
            .filter { !$0.isEmpty }
        guard !queries.isEmpty else { return nil }

        let symbol = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        var best: (bank: SeedData.SynonymBank, score: Double)?

        for bank in SeedData.synonymBanks {
            var score = scoreBank(bank, queries: queries, symbol: symbol)
            if let kind {
                score += kindAffinity(bank.kind, preferred: kind)
            }
            if score > familyThreshold, best == nil || score > best!.score {
                best = (bank, score)
            }
        }
        return best?.bank
    }

    private static func scoreBank(
        _ bank: SeedData.SynonymBank,
        queries: [String],
        symbol: String
    ) -> Double {
        var score = 0.0
        let bankNames = [bank.nameRu, bank.nameEn].map(TextNormalizer.normalize)
        let bankStems = Set(bankNames.map(stem))
        let keywordNorms = bank.keywords.map(TextNormalizer.normalize).filter { !$0.isEmpty }
        let keywordStems = Set(keywordNorms.map(stem))

        for q in queries {
            let qStem = stem(q)
            for bn in bankNames {
                if q == bn {
                    score += 12
                } else if q.contains(bn) || bn.contains(q) {
                    score += 7
                } else if tokenOverlapScore(q, bn) > 0 {
                    score += tokenOverlapScore(q, bn)
                } else if prefixSimilarity(q, bn) >= 0.7, min(q.count, bn.count) >= 4 {
                    score += 4
                }
            }
            if bankStems.contains(qStem), qStem.count >= 3 {
                score += 5
            }

            for kw in keywordNorms {
                if q == kw {
                    score += 9
                } else if q.contains(kw) || kw.contains(q), min(q.count, kw.count) >= 3 {
                    score += 4
                } else if keywordStems.contains(qStem), qStem.count >= 3, stem(kw) == qStem {
                    score += 3.5
                } else if tokenOverlapScore(q, kw) >= 3 {
                    score += 3
                }
            }

            // Multi-token query: any token hitting a keyword/name
            for token in q.split(separator: " ").map(String.init) where token.count >= 3 {
                let tStem = stem(token)
                if bankNames.contains(token) || keywordNorms.contains(token) {
                    score += 5
                } else if bankStems.contains(tStem) || keywordStems.contains(tStem) {
                    score += 3.5
                } else if keywordNorms.contains(where: { $0.contains(token) || token.contains($0) }) {
                    score += 2.5
                }
            }
        }

        if !symbol.isEmpty, symbol == bank.symbolName {
            score += 5
        }

        return score
    }

    private static func kindAffinity(_ bank: CategoryKind, preferred: CategoryKind) -> Double {
        if bank == preferred || bank == .both || preferred == .both { return 1.5 }
        return -2.0
    }

    // MARK: - Name-derived starters

    private static func derivedFromNames(ru: String, en: String) -> [String] {
        var out: [String] = []
        for raw in [ru, en] where !raw.isEmpty {
            let norm = TextNormalizer.normalize(raw)
            if !norm.isEmpty { out.append(norm) }

            // ё→е already in normalize; also keep original lowercased if it differed
            let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lower != norm, !lower.isEmpty { out.append(lower) }

            for token in norm.split(separator: " ").map(String.init) where token.count >= 2 {
                out.append(token)
                let s = stem(token)
                if s != token, s.count >= 3 { out.append(s) }
            }

            let wholeStem = stem(norm.replacingOccurrences(of: " ", with: ""))
            if wholeStem.count >= 3, wholeStem != norm {
                out.append(wholeStem)
            }
        }
        return out
    }

    /// When no family matches, pull individual synonyms whose stems/tokens sit near the name.
    private static func nearbySynonyms(from names: [String]) -> [String] {
        let tokens = Set(
            names
                .flatMap { TextNormalizer.normalize($0).split(separator: " ").map(String.init) }
                .filter { $0.count >= 3 }
                .flatMap { [$0, stem($0)] }
        )
        guard !tokens.isEmpty else { return [] }

        var hits: [String] = []
        for bank in SeedData.synonymBanks {
            for keyword in bank.keywords {
                let kn = TextNormalizer.normalize(keyword)
                let ks = stem(kn)
                if tokens.contains(kn) || tokens.contains(ks)
                    || tokens.contains(where: { kn.contains($0) || $0.contains(kn) || stem($0) == ks })
                {
                    hits.append(keyword)
                }
            }
        }
        return hits
    }

    // MARK: - Helpers

    private static func tokenOverlapScore(_ a: String, _ b: String) -> Double {
        let ta = Set(a.split(separator: " ").map { stem(String($0)) }.filter { $0.count >= 2 })
        let tb = Set(b.split(separator: " ").map { stem(String($0)) }.filter { $0.count >= 2 })
        let shared = ta.intersection(tb)
        guard !shared.isEmpty else { return 0 }
        return Double(shared.count) * 2.5
    }

    private static func prefixSimilarity(_ a: String, _ b: String) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var common = 0
        for (ca, cb) in zip(a, b) {
            if ca == cb { common += 1 } else { break }
        }
        return Double(common) / Double(max(a.count, b.count))
    }

    /// Light RU/EN stem: strip common endings so «зарплату» ≈ «зарплат», «gifts» ≈ «gift».
    static func stem(_ token: String) -> String {
        var t = TextNormalizer.normalize(token)
        guard t.count >= 4 else { return t }

        let endings = [
            "иями", "ями", "ами", "ией", "иею", "ою", "ею",
            "ого", "ему", "ому", "ыми", "ими",
            "ой", "ей", "ом", "ем", "ам", "ям", "ах", "ях", "ых", "их",
            "ую", "юю", "ая", "яя", "ое", "ее", "ые", "ие",
            "ов", "ев", "ин", "ын", "ий", "ый", "ть",
            "ing", "tion", "ments", "ment", "ness", "ies", "ers",
            "ed", "es", "ly", "er", "s",
            "а", "я", "у", "ю", "ы", "и", "е", "о", "ь",
        ]

        for ending in endings {
            guard t.hasSuffix(ending) else { continue }
            let cut = t.count - ending.count
            if cut >= 3 {
                t = String(t.prefix(cut))
                break
            }
        }
        return t
    }

    private static func dedupe(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = TextNormalizer.normalize(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(trimmed)
        }
        return out
    }
}
