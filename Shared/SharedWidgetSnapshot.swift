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

    static var empty: SharedWidgetSnapshot {
        .init(
            updatedAt: .now,
            todayExpense: 0,
            monthBalance: 0,
            monthExpense: 0,
            currencySymbol: "Br",
            budgetEnabled: false,
            budgetAmount: 0,
            budgetSpent: 0
        )
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
