import SwiftUI

struct WatchRecentView: View {
    @EnvironmentObject private var store: WatchStore

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.snapshot.recent.isEmpty {
                    ContentUnavailableView(
                        isRussian ? "Пока пусто" : "No entries",
                        systemImage: "tray",
                        description: Text(isRussian ? "Добавьте расход на часах или iPhone" : "Add on Watch or iPhone")
                    )
                } else {
                    List {
                        ForEach(store.snapshot.recent) { tx in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(categoryName(for: tx.categoryId))
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(
                                        (tx.isExpense ? "−" : "+")
                                            + SharedMoneyFormat.currency(tx.amount, code: tx.currency)
                                    )
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                }
                                if let note = tx.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isRussian ? "Недавние" : "Recent")
        }
    }

    private func categoryName(for id: String) -> String {
        store.snapshot.categories.first { $0.id == id }?.displayName(isRussian: isRussian)
            ?? id
    }
}
