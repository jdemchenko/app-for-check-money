import Foundation
import SwiftData

@Model
final class MoneyCategory {
    @Attribute(.unique) var id: String
    var nameRu: String
    var nameEn: String
    /// "expense" | "income" | "both"
    var kindRaw: String
    var keywordsCSV: String
    var colorHex: String
    var symbolName: String
    var isDefault: Bool
    var sortOrder: Int

    init(
        id: String = UUID().uuidString,
        nameRu: String,
        nameEn: String,
        kind: CategoryKind,
        keywords: [String],
        colorHex: String,
        symbolName: String,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.nameRu = nameRu
        self.nameEn = nameEn
        self.kindRaw = kind.rawValue
        self.keywordsCSV = keywords.joined(separator: ",")
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var keywords: [String] {
        get {
            keywordsCSV
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            keywordsCSV = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    func displayName(locale: Locale = .current) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        return code.hasPrefix("ru") ? nameRu : nameEn
    }
}

enum CategoryKind: String, CaseIterable, Identifiable, Codable {
    case expense
    case income
    case both

    var id: String { rawValue }

    func matches(_ type: TransactionType) -> Bool {
        switch self {
        case .both: return true
        case .expense: return type == .expense
        case .income: return type == .income
        }
    }
}

enum TransactionType: String, CaseIterable, Identifiable, Codable {
    case expense
    case income

    var id: String { rawValue }
}
