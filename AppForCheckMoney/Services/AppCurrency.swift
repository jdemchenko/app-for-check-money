import Foundation
import SwiftUI

/// App display / entry currency. Amounts are stored as plain numbers; no FX conversion.
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

    /// Compact symbol for lists and the balance hero (`Br` for Belarusian ruble).
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
}

@MainActor
final class CurrencySettings: ObservableObject {
    static let shared = CurrencySettings()
    private static let storageKey = "app.currency.code"

    @Published var currency: AppCurrency {
        didSet {
            UserDefaults.standard.set(currency.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let stored = AppCurrency(rawValue: raw) {
            currency = stored
        } else {
            currency = .byn
        }
    }
}
