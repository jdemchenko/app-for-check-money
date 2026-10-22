import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        WatchDictateView()
            .onAppear { store.requestRefresh() }
    }
}
