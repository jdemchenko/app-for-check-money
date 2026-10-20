import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CheckMoney")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(SharedMoneyFormat.currency(store.snapshot.balance, code: store.snapshot.displayCurrency))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(isRussian ? "Этот месяц" : "This month")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Divider().opacity(0.3)

                    HStack {
                        Text(isRussian ? "Сегодня" : "Today")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text("−" + SharedMoneyFormat.currency(
                            store.snapshot.todayExpense,
                            code: store.snapshot.displayCurrency
                        ))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.orange)
                    }

                    if !store.isReachable {
                        Text(isRussian ? "iPhone не рядом — кэш" : "iPhone away — cached")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .navigationTitle(isRussian ? "Обзор" : "Overview")
        }
    }
}
