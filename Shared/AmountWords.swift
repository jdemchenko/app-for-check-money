import Foundation

/// Parses numeric and spelled Russian/English amounts, including «X рублей Y копеек»
/// and hybrid speech forms like «тыща 200» → 1200.
enum AmountWords {
    private static let ones: [String: Int] = [
        "ноль": 0, "один": 1, "одна": 1, "два": 2, "две": 2, "три": 3, "четыре": 4,
        "пять": 5, "шесть": 6, "семь": 7, "восемь": 8, "девять": 9,
        "десять": 10, "одиннадцать": 11, "двенадцать": 12, "тринадцать": 13,
        "четырнадцать": 14, "пятнадцать": 15, "шестнадцать": 16, "семнадцать": 17,
        "восемнадцать": 18, "девятнадцать": 19,
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]

    private static let tens: [String: Int] = [
        "двадцать": 20, "тридцать": 30, "сорок": 40, "пятьдесят": 50,
        "шестьдесят": 60, "семьдесят": 70, "восемьдесят": 80, "девяносто": 90,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    private static let hundreds: [String: Int] = [
        "сто": 100, "двести": 200, "триста": 300, "четыреста": 400,
        "пятьсот": 500, "шестьсот": 600, "семьсот": 700, "восемьсот": 800,
        "девятьсот": 900,
        "hundred": 100,
    ]

    /// «тысяча» and speech shortenings («тыща», «тыс»).
    private static let thousandWords: Set<String> = [
        "тысяча", "тысячи", "тысяч", "тыща", "тыщи", "тыс",
        "thousand", "thousands",
    ]

    /// All tokens that can appear inside a spelled amount (for note stripping).
    static var spelledTokens: Set<String> {
        var set = Set(ones.keys)
        set.formUnion(tens.keys)
        set.formUnion(hundreds.keys)
        set.formUnion(thousandWords)
        set.formUnion([
            "миллион", "миллиона", "миллионов", "million",
            "итого", "total",
        ])
        return set
    }

    /// Best-effort amount from free-form speech/text.
    static func parse(from text: String) -> Double? {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }

        // «итого 7 рублей 40 копеек» / «7 руб 40 коп»
        if let withKopeks = parseRublesAndKopeks(normalized) {
            return withKopeks
        }

        // Spelled / hybrid («тыща 200» → 1200) before bare digits so we don't keep only 200.
        if let spelled = parseSpelled(normalized) {
            return Double(spelled)
        }

        if let digits = parseDigitAmount(normalized) {
            return digits
        }

        return nil
    }

    /// Removes spelled number words so notes keep only the description.
    static func stripSpelled(from text: String) -> String {
        var working = text
        for token in spelledTokens.sorted(by: { $0.count > $1.count }) {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            let pattern = #"(?i)(?<![0-9A-Za-zА-Яа-яЁё])\#(escaped)(?![0-9A-Za-zА-Яа-яЁё])"#
            working = working.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return working
    }

    private static func parseRublesAndKopeks(_ text: String) -> Double? {
        let patterns = [
            #"(\d+)\s*(?:руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br)?\s*(\d{1,2})\s*(?:копе(?:ек|йки|йка)|коп\.?|cents?)"#,
            #"итого\s+(\d+)[.,]?(\d{1,2})?"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = re.firstMatch(in: text, options: [], range: range) else { continue }
            if match.numberOfRanges >= 3,
               let r1 = Range(match.range(at: 1), in: text) {
                let whole = Double(text[r1]) ?? 0
                var frac = 0.0
                if let r2 = Range(match.range(at: 2), in: text), !text[r2].isEmpty {
                    let raw = String(text[r2])
                    if raw.count == 1 {
                        frac = (Double(raw) ?? 0) / 10
                    } else {
                        frac = (Double(raw) ?? 0) / 100
                    }
                }
                let value = whole + frac
                if value > 0 { return (value * 100).rounded() / 100 }
            }
        }
        return nil
    }

    private static func parseDigitAmount(_ text: String) -> Double? {
        var cleaned = text.replacingOccurrences(
            of: #"(\d)\s+(\d{3})\b"#,
            with: "$1$2",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        let patterns = [
            #"(?:итого\s+)?(\d+(?:\.\d{1,2})?)\s*(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?|копе(?:ек|йки)?)"#,
            #"(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?)\s*(\d+(?:\.\d{1,2})?)"#,
            #"(\d+\.\d{1,2})"#,
            #"(\d{1,7})"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = re.firstMatch(in: cleaned, options: [], range: range),
               match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: cleaned),
               let value = Double(cleaned[r]), value > 0 {
                return (value * 100).rounded() / 100
            }
        }
        return nil
    }

    /// Spelled amounts + hybrid «тыща 200» / «две тысячи 50».
    private static func parseSpelled(_ text: String) -> Int? {
        let tokens = text
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)

        var best: Int?
        var i = 0
        while i < tokens.count {
            var value = 0
            var chunk = 0
            var consumed = 0
            var j = i
            var sawNumber = false
            var sawThousand = false

            while j < tokens.count {
                let t = tokens[j]

                if thousandWords.contains(t) {
                    let base = chunk == 0 ? 1 : chunk
                    value += base * 1000
                    chunk = 0
                    sawNumber = true
                    sawThousand = true
                    consumed += 1
                    j += 1
                    continue
                }

                // Digits after (or inside) a number phrase: «тыща 200», «две тысячи 50»
                if let digit = Int(t), t.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
                    if sawNumber {
                        chunk += digit
                        consumed += 1
                        j += 1
                        continue
                    }
                    break
                }

                if let h = hundreds[t] {
                    chunk += h
                    sawNumber = true
                    consumed += 1
                    j += 1
                    continue
                }
                if let ten = tens[t] {
                    chunk += ten
                    sawNumber = true
                    consumed += 1
                    j += 1
                    continue
                }
                if let one = ones[t] {
                    chunk += one
                    sawNumber = true
                    consumed += 1
                    j += 1
                    continue
                }
                if ["и", "and"].contains(t), sawNumber {
                    consumed += 1
                    j += 1
                    continue
                }
                break
            }

            if sawNumber {
                value += chunk
                // Prefer hybrid thousand+digits (or any spelled) over a later bare digit alone.
                if value > 0 {
                    if sawThousand || best == nil || value > (best ?? 0) {
                        best = max(best ?? 0, value)
                    }
                }
                i += max(consumed, 1)
            } else {
                i += 1
            }
        }
        return best
    }
}
