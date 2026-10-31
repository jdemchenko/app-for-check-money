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
    /// Session «в рб» stamps `.byn` for bare «руб».
    var currency: AppCurrency?
    /// Recurring cadence from speech (`weekly` / `monthly`).
    var frequency: RecurringFrequency?
    /// Calendar day offset vs today: `0` today, `-1` yesterday.
    var dayOffset: Int?
    /// `morning` / `evening` from speech (optional).
    var dayPart: String?
    /// Subscription brand id for confirm logos (`apple_music`, `spotify`, …).
    var subscriptionBrand: String?

    /// Happy-path autosave: amount + keyword category, not a recurring rule.
    var isAutosaveReady: Bool {
        guard frequency == nil else { return false }
        guard let amount, amount > 0 else { return false }
        return categoryMatchedByKeyword && categoryId != nil
    }

    var isRecurring: Bool { frequency != nil }

    init(
        amount: Double?,
        type: TransactionType?,
        categoryId: String?,
        note: String,
        rawText: String,
        categoryMatchedByKeyword: Bool,
        currency: AppCurrency?,
        frequency: RecurringFrequency? = nil,
        dayOffset: Int? = nil,
        dayPart: String? = nil,
        subscriptionBrand: String? = nil
    ) {
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.note = note
        self.rawText = rawText
        self.categoryMatchedByKeyword = categoryMatchedByKeyword
        self.currency = currency
        self.frequency = frequency
        self.dayOffset = dayOffset
        self.dayPart = dayPart
        self.subscriptionBrand = subscriptionBrand
    }

    init(from shared: SharedVoiceDraft) {
        amount = shared.amount
        type = shared.typeRaw.flatMap { TransactionType(rawValue: $0) }
        categoryId = shared.categoryId
        note = shared.note
        rawText = shared.rawText
        categoryMatchedByKeyword = shared.categoryMatchedByKeyword
        currency = shared.currencyRaw.flatMap { AppCurrency(rawValue: $0) }
        frequency = shared.frequencyRaw.flatMap { RecurringFrequency(rawValue: $0) }
        dayOffset = shared.dayOffset
        dayPart = shared.dayPart
        subscriptionBrand = shared.subscriptionBrandRaw
    }

    var subscriptionBrandTitle: String? {
        guard let subscriptionBrand else { return nil }
        return SharedVoiceParser.SubscriptionBrand.displayName(for: subscriptionBrand)
    }

    var subscriptionBrandSymbol: String? {
        guard let subscriptionBrand else { return nil }
        return SharedVoiceParser.SubscriptionBrand.symbolName(for: subscriptionBrand)
    }

    /// Resolve speech-relative date to a concrete `Date` for save.
    func resolvedDate(now: Date = .now, calendar: Calendar = .current) -> Date {
        var date = now
        if let dayOffset {
            date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))
                ?? now
        }
        switch dayPart {
        case "morning":
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        case "evening":
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date) ?? date
        default:
            return date
        }
    }

    /// Short confirm-panel label: «вчера», «сегодня утром», …
    func dateLabel() -> String? {
        guard dayOffset != nil || dayPart != nil else { return nil }
        let day: String
        switch dayOffset {
        case -2: day = L10n.string("date.dayBeforeYesterday")
        case -1: day = L10n.string("date.yesterday")
        case 0: day = L10n.string("date.today")
        case .some(let n) where n < 0:
            day = L10n.string("date.yesterday")
        default:
            day = L10n.string("date.today")
        }
        switch dayPart {
        case "morning":
            return day + " " + L10n.string("date.morning")
        case "evening":
            return day + " " + L10n.string("date.evening")
        default:
            return day
        }
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

    /// One utterance → one or more drafts (multi-expense / recurring).
    static func parseMany(
        rawText: String,
        categories: [MoneyCategory]
    ) -> [VoiceDraft] {
        let sharedCats = categories.map { $0.asSharedDTO }
        return SharedVoiceParser.parseMany(rawText: rawText, categories: sharedCats)
            .map(VoiceDraft.init(from:))
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
