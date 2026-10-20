import Foundation

enum TextNormalizer {
 {
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
