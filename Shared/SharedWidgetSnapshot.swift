import Foundation
import Security

/// Codable payload shared between the iPhone app and the phone widget extension.
struct SharedWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var todayExpense: Double
    var monthBalance: Double
    var monthExpense: Double
    var currencySymbol: String
    var budgetEnabled: Bool
    var budgetAmount: Double
    var budgetSpent: Double
    /// Last N calendar days of expense totals (display currency), oldest → newest. Empty on legacy snapshots.
    var recentDailyExpenses: [Double]

    static var empty: SharedWidgetSnapshot {
        .init(
            updatedAt: .now,
            todayExpense: 0,
            monthBalance: 0,
            monthExpense: 0,
            currencySymbol: "Br",
            budgetEnabled: false,
            budgetAmount: 0,
            budgetSpent: 0,
            recentDailyExpenses: Array(repeating: 0, count: 7)
        )
    }

    init(
        updatedAt: Date,
        todayExpense: Double,
        monthBalance: Double,
        monthExpense: Double,
        currencySymbol: String,
        budgetEnabled: Bool,
        budgetAmount: Double,
        budgetSpent: Double,
        recentDailyExpenses: [Double] = []
    ) {
        self.updatedAt = updatedAt
        self.todayExpense = todayExpense
        self.monthBalance = monthBalance
        self.monthExpense = monthExpense
        self.currencySymbol = currencySymbol
        self.budgetEnabled = budgetEnabled
        self.budgetAmount = budgetAmount
        self.budgetSpent = budgetSpent
        self.recentDailyExpenses = recentDailyExpenses
    }

    enum CodingKeys: String, CodingKey {
        case updatedAt, todayExpense, monthBalance, monthExpense
        case currencySymbol, budgetEnabled, budgetAmount, budgetSpent
        case recentDailyExpenses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        todayExpense = try c.decode(Double.self, forKey: .todayExpense)
        monthBalance = try c.decode(Double.self, forKey: .monthBalance)
        monthExpense = try c.decode(Double.self, forKey: .monthExpense)
        currencySymbol = try c.decode(String.self, forKey: .currencySymbol)
        budgetEnabled = try c.decode(Bool.self, forKey: .budgetEnabled)
        budgetAmount = try c.decode(Double.self, forKey: .budgetAmount)
        budgetSpent = try c.decode(Double.self, forKey: .budgetSpent)
        recentDailyExpenses = try c.decodeIfPresent([Double].self, forKey: .recentDailyExpenses) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(todayExpense, forKey: .todayExpense)
        try c.encode(monthBalance, forKey: .monthBalance)
        try c.encode(monthExpense, forKey: .monthExpense)
        try c.encode(currencySymbol, forKey: .currencySymbol)
        try c.encode(budgetEnabled, forKey: .budgetEnabled)
        try c.encode(budgetAmount, forKey: .budgetAmount)
        try c.encode(budgetSpent, forKey: .budgetSpent)
        try c.encode(recentDailyExpenses, forKey: .recentDailyExpenses)
    }
}

/// Persists widget snapshot via **Keychain Sharing** (not App Groups).
/// Personal Team supports `keychain-access-groups`; App Groups do not.
///
/// Access group comes from Info.plist (`CheckMoneyKeychainAccessGroup`), expanded at
/// build time — no `SecStaticCode*` (unavailable under `APPLICATION_EXTENSION_API_ONLY`).
enum SharedWidgetSnapshotStore {
    private static let service = "com.jdemchenko.AppForCheckMoney.widgetSnapshot"
    private static let account = "v1"
    private static let defaultsKey = "widget.snapshot.v1"
    private static let infoKey = "CheckMoneyKeychainAccessGroup"

    static func save(_ snapshot: SharedWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        keychainWrite(data)
    }

    static func load() -> SharedWidgetSnapshot? {
        if let data = keychainRead() ?? UserDefaults.standard.data(forKey: defaultsKey) {
            return try? JSONDecoder().decode(SharedWidgetSnapshot.self, from: data)
        }
        return nil
    }

    // MARK: - Keychain

    private static func keychainWrite(_ data: Data) {
        var query: [String: Any] = baseQuery()
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func keychainRead() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = sharedAccessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    /// Shared group from Info.plist build-setting expansion (app + widget must match).
    private static func sharedAccessGroup() -> String? {
        if let injected = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String {
            let trimmed = injected.trimmingCharacters(in: .whitespacesAndNewlines)
            // Reject unexpanded build variables.
            if !trimmed.isEmpty, !trimmed.contains("$(") {
                return trimmed
            }
        }
        return nil
    }
}
