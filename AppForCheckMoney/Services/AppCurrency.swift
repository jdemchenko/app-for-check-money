import Foundation
import SwiftUI

/// Supported currencies. Each transaction stores its own code; Settings only
/// sets **display** currency (totals) and the **default entry** currency for new ops.
enum AppCurrency: String, CaseIterable, Identifiable, Codable {
    case byn
    case rub
    case usd
    case eur

    var id: String { rawValue }

    var code: String {
        switch self {
        case .byn: return "BYN"
        case .rub: return "RUB"
        case .usd: return "USD"
        case .eur: return "EUR"
        }
    }

    /// Compact symbol (`Br` for Belarusian ruble).
    var displaySymbol: String {
        switch self {
        case .byn: return "Br"
        case .rub: return "₽"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var localizedTitle: String {
        switch self {
        case .byn: return L10n.string("currency.byn")
        case .rub: return L10n.string("currency.rub")
        case .usd: return L10n.string("currency.usd")
        case .eur: return L10n.string("currency.eur")
        }
    }

    static func parse(_ raw: String?) -> AppCurrency {
        guard let raw, let value = AppCurrency(rawValue: raw.lowercased()) else {
            return .byn
        }
        return value
    }
}

/// Conversion for **display totals only**.
/// Stored transaction amounts are never rewritten when the user changes Settings.
///
/// Live rates from myfin.by (НБРБ board) via `ExchangeRateStore`, with static BYN-pivot fallback.
enum CurrencyConverter {
    static func convert(_ amount: Double, from: AppCurrency, to: AppCurrency) -> Double {
        guard from != to else { return amount }
        let rates = ExchangeRateStore.currentRates()
        let inByn = amount * (rates[from] ?? ExchangeRateStore.staticBynPerUnit[from] ?? 1)
        let rateTo = rates[to] ?? ExchangeRateStore.staticBynPerUnit[to] ?? 1
        guard rateTo > 0 else { return amount }
        return (inByn / rateTo * 100).rounded() / 100
    }

    /// Short footnote for Settings / Stats (includes myfin.by + last updated when live).
    @MainActor
    static var ratesFootnote: String {
        ExchangeRateStore.shared.ratesFootnote
    }
}

@MainActor
final class CurrencySettings: ObservableObject {
    static let shared = CurrencySettings()

    private static let displayKey = "app.currency.display"
    private static let entryKey = "app.currency.entry"
    /// Legacy key from the global-currency era — migrates to both display + entry once.
    private static let legacyKey = "app.currency.code"

    /// Currency used for Home / Stats totals (converts each tx; does not mutate storage).
    @Published var displayCurrency: AppCurrency {
        didSet { UserDefaults.standard.set(displayCurrency.rawValue, forKey: Self.displayKey) }
    }

    /// Default currency stamped onto new manual / voice transactions.
    @Published var entryCurrency: AppCurrency {
        didSet { UserDefaults.standard.set(entryCurrency.rawValue, forKey: Self.entryKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        if let display = defaults.string(forKey: Self.displayKey).flatMap(AppCurrency.init(rawValue:)) {
            displayCurrency = display
        } else if let legacy = defaults.string(forKey: Self.legacyKey).flatMap(AppCurrency.init(rawValue:)) {
            displayCurrency = legacy
        } else {
            displayCurrency = .byn
        }

        if let entry = defaults.string(forKey: Self.entryKey).flatMap(AppCurrency.init(rawValue:)) {
            entryCurrency = entry
        } else if let legacy = defaults.string(forKey: Self.legacyKey).flatMap(AppCurrency.init(rawValue:)) {
            entryCurrency = legacy
        } else {
            entryCurrency = .byn
        }
    }

    /// Back-compat alias used by older call sites.
    var currency: AppCurrency {
        get { displayCurrency }
        set { displayCurrency = newValue }
    }
}
