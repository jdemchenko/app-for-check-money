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
enum SharedWidgetSnapshotStore {
    private static let service = "com.jdemchenko.AppForCheckMoney.widgetSnapshot"
    private static let account = "v1"
    private static let defaultsKey = "widget.snapshot.v1"

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
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = sharedAccessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func keychainRead() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let group = sharedAccessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    /// First `keychain-access-groups` entry from the signed entitlements (shared by app + widget).
    private static func sharedAccessGroup() -> String? {
        if let injected = Bundle.main.object(forInfoDictionaryKey: "CheckMoneyKeychainAccessGroup") as? String,
           !injected.isEmpty,
           !injected.contains("$(") {
            return injected
        }
        return entitlementsAccessGroup()
    }

    private static func entitlementsAccessGroup() -> String? {
        guard let url = Bundle.main.executableURL else { return nil }
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }

        var info: CFDictionary?
        // kSecCSSigningInformation == 2
        let flags = SecCSFlags(rawValue: 2)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any]
        else { return nil }

        let entitlements =
            (dict["entitlements"] as? [String: Any])
            ?? (dict[String(kSecCodeInfoEntitlementsDict)] as? [String: Any])
        guard let groups = entitlements?["keychain-access-groups"] as? [String] else {
            // Last resort: TeamID.baseBundle from application-identifier.
            if let appId = entitlements?["application-identifier"] as? String
                ?? (dict["application-identifier"] as? String),
               let dot = appId.firstIndex(of: ".") {
                let team = String(appId[..<dot])
                return "\(team).com.jdemchenko.AppForCheckMoney"
            }
            return nil
        }
        // Prefer the base app id group (no .widgets / .watchkitapp suffix).
        if let base = groups.first(where: {
            $0.hasSuffix(".AppForCheckMoney") && !$0.contains(".widgets")
        }) {
            return base
        }
        return groups.first
    }
}
