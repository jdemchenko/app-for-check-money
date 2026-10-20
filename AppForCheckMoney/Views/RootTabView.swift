import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case stats
    case history
    case categories
}

/// Home / Stats / History / Categories — Add stays a Home sheet.
struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(L10n.string("tab.home"), systemImage: "house.fill")
                }
                .tag(AppTab.home)

            StatsView()
                .tabItem {
                    Label(L10n.string("tab.stats"), systemImage: "chart.bar.fill")
                }
                .tag(AppTab.stats)

            HistoryView()
                .tabItem {
                    Label(L10n.string("tab.history"), systemImage: "list.bullet")
                }
                .tag(AppTab.history)

            CategoriesView()
                .tabItem {
                    Label(L10n.string("tab.categories"), systemImage: "folder.fill")
                }
                .tag(AppTab.categories)
        }
        .tint(Color.primary)
        .task {
            ExchangeRateStore.shared.refreshIfNeeded()
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self], inMemory: true)
}
