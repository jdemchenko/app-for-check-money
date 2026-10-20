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
                // Defer Watch sync so Home / Speech / tabs come up first.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    PhoneWatchSync.shared.start(modelContext: container.mainContext)
                }
            case .failure(let error):
                assertionFailure("SwiftData container failed: \(error)")
            }
        }
    }
}
