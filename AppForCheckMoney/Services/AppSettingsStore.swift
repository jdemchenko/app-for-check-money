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
        static let categoryBudgets = "settings.budget.categories"
        static let lockEnabled = "settings.lock.enabled"
        static let onboardingDone = "settings.onboarding.done"
        static let iCloudPrefer = "settings.icloud.prefer"
        static let reminderEnabled = "settings.reminder.enabled"
        static let reminderHour = "settings.reminder.hour"
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

    /// Optional per-category monthly limits (same currency as `budgetCurrency`).
    @Published var categoryBudgets: [String: Double] {
        didSet { persistCategoryBudgets() }
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

    @Published var reminderEnabled: Bool {
        didSet {
            defaults.set(reminderEnabled, forKey: Key.reminderEnabled)
            Task { await ReminderService.apply(enabled: reminderEnabled, hour: reminderHour) }
        }
    }

    /// Local hour (0…23) for the optional daily log nudge.
    @Published var reminderHour: Int {
        didSet {
            defaults.set(reminderHour, forKey: Key.reminderHour)
            Task { await ReminderService.apply(enabled: reminderEnabled, hour: reminderHour) }
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let enabled = defaults.bool(forKey: Key.budgetEnabled)
        let storedAmount = defaults.double(forKey: Key.budgetAmount)
        let amount = storedAmount > 0 ? storedAmount : 1000
        let currency = AppCurrency.parse(defaults.string(forKey: Key.budgetCurrency))
        let lock = defaults.bool(forKey: Key.lockEnabled)
        let preferCloud = defaults.bool(forKey: Key.iCloudPrefer)
        let reminderOn = defaults.bool(forKey: Key.reminderEnabled)
        let hourStored = defaults.object(forKey: Key.reminderHour) as? Int
        let hour = hourStored ?? 21

        let cats: [String: Double]
        if let data = defaults.data(forKey: Key.categoryBudgets),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            cats = decoded
        } else {
            cats = [:]
        }

        let done: Bool
        if defaults.object(forKey: Key.onboardingDone) != nil {
            done = defaults.bool(forKey: Key.onboardingDone)
        } else {
            // Upgrade path: users who already picked currencies skip the new one-screen intro.
            let returningUser = defaults.object(forKey: "app.currency.display") != nil
                || defaults.object(forKey: "app.currency.entry") != nil
                || defaults.object(forKey: "app.currency.code") != nil
            done = returningUser
            defaults.set(done, forKey: Key.onboardingDone)
        }

        // Assign all stored properties only after locals are ready (Swift init ordering).
        budgetEnabled = enabled
        budgetAmount = amount
        budgetCurrency = currency
        categoryBudgets = cats
        lockEnabled = lock
        preferiCloudSync = preferCloud
        reminderEnabled = reminderOn
        reminderHour = max(0, min(23, hour))
        onboardingDone = done
    }

    func categoryBudget(for id: String) -> Double? {
        guard let value = categoryBudgets[id], value > 0 else { return nil }
        return value
    }

    func setCategoryBudget(_ amount: Double?, for id: String) {
        var next = categoryBudgets
        if let amount, amount > 0 {
            next[id] = amount
        } else {
            next.removeValue(forKey: id)
        }
        categoryBudgets = next
    }

    private func persistCategoryBudgets() {
        if let data = try? JSONEncoder().encode(categoryBudgets) {
            defaults.set(data, forKey: Key.categoryBudgets)
        }
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
