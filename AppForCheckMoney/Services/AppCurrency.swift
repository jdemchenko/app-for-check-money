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

/// Approximate conversion for **display totals only**.
/// Stored transaction amounts are never rewritten when the user changes Settings.
///
/// Approach: static mid-market-style rates with **BYN as the pivot**.
/// Not live FX — good enough for multi-currency overviews; refresh rates in app updates.
enum CurrencyConverter {
    /// BYN per 1 unit of currency (approximate).
    private static let bynPerUnit: [AppCurrency: Double] = [
        .byn: 1.0,
        .usd: 3.25,
        .eur: 3.55,
        .rub: 0.036,
    ]

    static func convert(_ amount: Double, from: AppCurrency, to: AppCurrency) -> Double {
        guard from != to else { return amount }
        let inByn = amount * (bynPerUnit[from] ?? 1)
        let rateTo = bynPerUnit[to] ?? 1
        guard rateTo > 0 else { return amount }
        return (inByn / rateTo * 100).rounded() / 100
    }

    /// Short footnote for Settings / Stats.
    static var ratesFootnote: String {
        L10n.string("settings.ratesHint")
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
