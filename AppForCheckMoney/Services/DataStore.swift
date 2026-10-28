import Foundation
import SwiftData

enum DataStore {
    /// Builds the SwiftData container.
    /// CloudKit (`.automatic`) needs a **paid** Apple Developer team + iCloud capability.
    /// Personal Team keeps **local-only** storage so signing/run still works.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            MoneyTransaction.self,
            MoneyCategory.self,
            RecurringRule.self,
            MoneyAccount.self,
            MoneyGoal.self,
            MoneyDebt.self,
            MoneySpace.self,
        ])

        let preferCloud = UserDefaults.standard.bool(forKey: "settings.icloud.prefer")
        if preferCloud {
            do {
                let cloud = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
                return try ModelContainer(for: schema, configurations: [cloud])
            } catch {
                // Fall through to local — CloudKit often unavailable on Personal Team.
            }
        }

        let local = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [local])
    }

    /// Honest status for Settings UI.
    static var iCloudStatusMessage: String {
        let prefer = UserDefaults.standard.bool(forKey: "settings.icloud.prefer")
        if !prefer {
            return L10n.string("icloud.off")
        }
        return L10n.string("icloud.personalTeamNote")
    }
}
