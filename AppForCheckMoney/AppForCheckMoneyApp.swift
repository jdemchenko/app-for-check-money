import SwiftUI
import SwiftData

@main
struct AppForCheckMoneyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self]) { result in
            switch result {
            case .success(let container):
                SeedData.ensureDefaults(in: container.mainContext)
            case .failure(let error):
                assertionFailure("SwiftData container failed: \(error)")
            }
        }
    }
}
