import SwiftUI

@main
struct CheckMoneyWatchApp: App {
    @ObservedObject private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
        }
    }
}
