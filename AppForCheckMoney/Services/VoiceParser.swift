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

    init(
        amount: Double?,
        type: TransactionType?,
        categoryId: String?,
        note: String,
        rawText: String,
        categoryMatchedByKeyword: Bool,
        currency: AppCurrency?
    ) {
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.note = note
        self.rawText = rawText
        self.categoryMatchedByKeyword = categoryMatchedByKeyword
        self.currency = currency
    }

    init(from shared: SharedVoiceDraft) {
        amount = shared.amount
        type = shared.typeRaw.flatMap { TransactionType(rawValue: $0) }
        categoryId = shared.categoryId
        note = shared.note
        rawText = shared.rawText
        categoryMatchedByKeyword = shared.categoryMatchedByKeyword
        currency = shared.currencyRaw.flatMap { AppCurrency(rawValue: $0) }
    }
}

/// Phone façade over shared NLP (`SharedVoiceParser` + `AmountWords`).
enum VoiceParser {
    static func parseAmount(from text: String) -> Double? {
        SharedVoiceParser.parseAmount(from: text)
    }

    static func inferType(from text: String) -> TransactionType? {
        SharedVoiceParser.inferType(from: text).flatMap { TransactionType(rawValue: $0) }
    }

    static func inferCurrency(from text: String) -> AppCurrency? {
        SharedVoiceParser.inferCurrency(from: text).flatMap { AppCurrency(rawValue: $0) }
    }

    static func parse(
        rawText: String,
        categories: [MoneyCategory]
    ) -> VoiceDraft {
        let sharedCats = categories.map { $0.asSharedDTO }
        let draft = SharedVoiceParser.parse(rawText: rawText, categories: sharedCats)
        return VoiceDraft(from: draft)
    }
}

extension MoneyCategory {
    var asSharedDTO: SharedCategoryDTO {
        SharedCategoryDTO(
            id: id,
            nameRu: nameRu,
            nameEn: nameEn,
            kindRaw: kindRaw,
            symbolName: symbolName,
            colorHex: colorHex,
            sortOrder: sortOrder,
            keywords: keywords
        )
    }
}

#if DEBUG
extension VoiceParser {
    static func debugSelfCheck(categories: [MoneyCategory]) -> [String] {
        SharedVoiceParser.debugSelfCheck(categories: categories.map(\.asSharedDTO))
    }
}
#endif
