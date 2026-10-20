import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        TabView {
            WatchHomeView()
            WatchAddView()
            WatchRecentView()
        }
        .tabViewStyle(.verticalPage)
        .onAppear { store.requestRefresh() }
    }
}
