import SwiftUI
import SwiftData

/// Home / Stats / History / Categories — Add stays a Home sheet.
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(L10n.string("tab.home"), systemImage: "house.fill")
                }

            StatsView()
                .tabItem {
                    Label(L10n.string("tab.stats"), systemImage: "chart.bar.fill")
                }

            HistoryView()
                .tabItem {
                    Label(L10n.string("tab.history"), systemImage: "list.bullet")
                }

            CategoriesView()
                .tabItem {
                    Label(L10n.string("tab.categories"), systemImage: "folder.fill")
                }
        }
        .tint(Color.primary)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self], inMemory: true)
}
