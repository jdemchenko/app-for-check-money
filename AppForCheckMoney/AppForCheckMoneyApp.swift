import SwiftUI
import SwiftData

@main
struct AppForCheckMoneyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .onAppear {
                    // WatchConnectivity activates when the model container is ready (see below).
                }
        }
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self]) { result in
            switch result {
            case .success(let container):
                SeedData.ensureDefaults(in: container.mainContext)
                Task { @MainActor in
                    PhoneWatchSync.shared.start(modelContext: container.mainContext)
                }
            case .failure(let error):
                assertionFailure("SwiftData container failed: \(error)")
            }
        }
    }
}
