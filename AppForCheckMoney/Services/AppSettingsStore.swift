import Foundation
import Combine

/// Lightweight preferences (budget, lock, onboarding). Not CloudKit-synced on Personal Team.
@MainActor
final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()

    private let defaults: UserDefaults
    private enum Key {
        static let budgetEnabled = "settings.budget.enabled"
        static let budgetAmount = "settings.budget.amount"
        static let budgetCurrency = "settings.budget.currency"
        static let lockEnabled = "settings.lock.enabled"
        static let onboardingDone = "settings.onboarding.done"
        static let iCloudPrefer = "settings.icloud.prefer"
    }

    @Published var budgetEnabled: Bool {
        didSet { defaults.set(budgetEnabled, forKey: Key.budgetEnabled) }
    }

    /// Monthly spend limit in `budgetCurrency` (display-side comparison uses conversion).
    @Published var budgetAmount: Double {
        didSet { defaults.set(budgetAmount, forKey: Key.budgetAmount) }
    }

    @Published var budgetCurrency: AppCurrency {
        didSet { defaults.set(budgetCurrency.rawValue, forKey: Key.budgetCurrency) }
    }

    @Published var lockEnabled: Bool {
        didSet { defaults.set(lockEnabled, forKey: Key.lockEnabled) }
    }

    @Published var onboardingDone: Bool {
        didSet { defaults.set(onboardingDone, forKey: Key.onboardingDone) }
    }

    /// User wants CloudKit when available (paid team). Default off for Personal Team safety.
    @Published var preferiCloudSync: Bool {
        didSet { defaults.set(preferiCloudSync, forKey: Key.iCloudPrefer) }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        budgetEnabled = defaults.bool(forKey: Key.budgetEnabled)
        let stored = defaults.double(forKey: Key.budgetAmount)
        budgetAmount = stored > 0 ? stored : 1000
        budgetCurrency = AppCurrency.parse(defaults.string(forKey: Key.budgetCurrency))
        lockEnabled = defaults.bool(forKey: Key.lockEnabled)
        if defaults.object(forKey: Key.onboardingDone) != nil {
            onboardingDone = defaults.bool(forKey: Key.onboardingDone)
        } else {
            // Upgrade path: users who already picked currencies skip the new one-screen intro.
            let returningUser = defaults.object(forKey: "app.currency.display") != nil
                || defaults.object(forKey: "app.currency.entry") != nil
                || defaults.object(forKey: "app.currency.code") != nil
            onboardingDone = returningUser
            defaults.set(onboardingDone, forKey: Key.onboardingDone)
        }
        preferiCloudSync = defaults.bool(forKey: Key.iCloudPrefer)
    }
}

enum PaymentMethod: String, CaseIterable, Identifiable, Codable {
    case unspecified = ""
    case cash
    case card

    var id: String { rawValue.isEmpty ? "unspecified" : rawValue }

    var title: String {
        switch self {
        case .unspecified: return L10n.string("payment.unspecified")
        case .cash: return L10n.string("payment.cash")
        case .card: return L10n.string("payment.card")
        }
    }

    var symbolName: String {
        switch self {
        case .unspecified: return "questionmark.circle"
        case .cash: return "banknote"
        case .card: return "creditcard"
        }
    }

    static func parse(_ raw: String?) -> PaymentMethod {
        guard let raw, let value = PaymentMethod(rawValue: raw) else { return .unspecified }
        return value
    }
}
