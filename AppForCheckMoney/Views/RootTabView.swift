import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case stats
    case history
    case categories
}

/// Home / Stats / History / Categories — Add stays a Home sheet.
/// Uses `Tab` (iOS 18+) so iOS 26 applies system Liquid Glass to the tab bar with no custom chrome.
struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.string("tab.home"), systemImage: "house.fill", value: AppTab.home) {
                HomeView(selectedTab: $selectedTab)
            }
            Tab(L10n.string("tab.stats"), systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView()
            }
            Tab(L10n.string("tab.history"), systemImage: "list.bullet", value: AppTab.history) {
                HistoryView()
            }
            Tab(L10n.string("tab.categories"), systemImage: "folder.fill", value: AppTab.categories) {
                CategoriesView()
            }
        }
        .tint(AppTheme.accent)
        .task {
            ExchangeRateStore.shared.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                PhoneWatchSync.shared.refreshAfterForeground()
            }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppSettingsStore.shared)
        .modelContainer(
            for: [
                MoneyTransaction.self, MoneyCategory.self, RecurringRule.self,
                MoneyAccount.self, MoneyGoal.self, MoneyDebt.self, MoneySpace.self,
            ],
            inMemory: true
        )
}
