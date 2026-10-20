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
    /// Formats with the user-selected app currency (default BYN → `Br`).
    @MainActor
    static func currency(_ value: Double) -> String {
        currency(value, code: CurrencySettings.shared.currency)
    }

    static func currency(_ value: Double, code: AppCurrency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        // Explicit symbols keep BYN as «Br» regardless of device locale quirks.
        switch code {
        case .byn:
            return "\(number) Br"
        case .rub:
            return "\(number) ₽"
        case .usd:
            return "$\(number)"
        case .eur:
            return "\(number) €"
        }
    }

    @MainActor
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
