import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(L10n.string("tab.home"), systemImage: "house.fill")
                }

            AddTransactionView()
                .tabItem {
                    Label(L10n.string("tab.add"), systemImage: "plus.circle.fill")
                }

            CategoriesView()
                .tabItem {
                    Label(L10n.string("tab.categories"), systemImage: "folder.fill")
                }

            HistoryView()
                .tabItem {
                    Label(L10n.string("tab.history"), systemImage: "list.bullet")
                }
        }
        .tint(Color(hex: "0A84FF"))
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [MoneyTransaction.self, MoneyCategory.self], inMemory: true)
}
