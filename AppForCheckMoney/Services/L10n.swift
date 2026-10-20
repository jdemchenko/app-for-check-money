import Foundation

/// Thin wrapper over String Catalog / Localizable.strings.
enum L10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static var isRussian: Bool {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code.hasPrefix("ru")
    }
}

enum MoneyFormat {
    static func currency(_ value: Double) -> String {
        let code = L10n.isRussian ? "RUB" : "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func signed(_ value: Double, type: TransactionType) -> String {
        let sign = type == .income ? "+" : "−"
        return sign + currency(value)
    }

    static func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return L10n.string("date.today")
        }
        if Calendar.current.isDateInYesterday(date) {
            return L10n.string("date.yesterday")
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
