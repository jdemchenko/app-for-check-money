import SwiftUI
import SwiftData

/// Three tabs only — Add is a sheet from Home to cut chrome.
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(L10n.string("tab.home"), systemImage: "house.fill")
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
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self], inMemory: true)
}
