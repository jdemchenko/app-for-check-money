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
    /// Formats a **native** amount in the given currency (row display).
    static func currency(_ value: Double, code: AppCurrency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        switch code {
        case .byn: return "\(number) Br"
        case .rub: return "\(number) ₽"
        case .usd: return "$\(number)"
        case .eur: return "\(number) €"
        }
    }

    /// Totals / balance in the Settings **display** currency.
    @MainActor
    static func displayCurrency(_ value: Double) -> String {
        currency(value, code: CurrencySettings.shared.displayCurrency)
    }

    @MainActor
    static func signed(_ value: Double, type: TransactionType, code: AppCurrency) -> String {
        let sign = type == .income ? "+" : "−"
        return sign + currency(value, code: code)
    }

    /// Transaction row: always show the tx’s own currency.
    @MainActor
    static func signed(transaction: MoneyTransaction) -> String {
        signed(transaction.amount, type: transaction.type, code: transaction.currency)
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

/// Period helpers for Stats / Home.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return L10n.string("stats.week")
        case .month: return L10n.string("stats.month")
        case .all: return L10n.string("stats.all")
        }
    }

    func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .week:
            guard let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            }
            return date >= start && date <= now.addingTimeInterval(86400)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: now)
            guard let start = calendar.date(from: comps) else { return false }
            return date >= start && date <= now.addingTimeInterval(86400)
        }
    }
}
