import SwiftUI
import SwiftData

/// Quiet hub for accounts, goals, debts, and the spaces shell.
struct LedgerHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    @Query(sort: \MoneyGoal.createdAt, order: .reverse) private var goals: [MoneyGoal]
    @Query(sort: \MoneyDebt.createdAt, order: .reverse) private var debts: [MoneyDebt]
    @Query private var spaces: [MoneySpace]
    @Query private var transactions: [MoneyTransaction]
    @ObservedObject private var currencySettings = CurrencySettings.shared

    @State private var showAccounts = false
    @State private var showGoals = false
    @State private var showDebts = false
    @State private var showSpaces = false

    private var totals: AccountLedger.Totals {
        AccountLedger.totals(
            accounts: accounts,
            transactions: transactions,
            displayCurrency: currencySettings.displayCurrency
        )
    }

    private var openDebts: Int { debts.filter { !$0.isSettled }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GlassPanel(padding: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.string("ledger.totalBalance"))
                                .font(.footnote.weight(.medium))
                                .themeSecondary()
                            Text(MoneyFormat.currency(totals.totalDisplay, code: totals.displayCurrency))
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                            Text(L10n.string("ledger.fxNote"))
                                .font(.caption2)
                                .themeTertiary()
                        }
                    }

                    row(
                        title: L10n.string("accounts.title"),
                        subtitle: String(
                            format: L10n.string("accounts.countFormat"),
                            accounts.filter { !$0.isArchived }.count
                        ),
                        symbol: "creditcard"
                    ) { showAccounts = true }

                    row(
                        title: L10n.string("goals.title"),
                        subtitle: String(format: L10n.string("goals.countFormat"), goals.count),
                        symbol: "target"
                    ) { showGoals = true }

                    row(
                        title: L10n.string("debt.title"),
                        subtitle: String(format: L10n.string("debt.openFormat"), openDebts),
                        symbol: "person.2"
                    ) { showDebts = true }

                    row(
                        title: L10n.string("space.title"),
                        subtitle: spaces.first?.name ?? L10n.string("space.privateDefaultName"),
                        symbol: "person.3"
                    ) { showSpaces = true }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("ledger.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showAccounts) { AccountsView() }
            .sheet(isPresented: $showGoals) { GoalsView() }
            .sheet(isPresented: $showDebts) { DebtsView() }
            .sheet(isPresented: $showSpaces) { SpacesView() }
        }
    }

    private func row(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 28)
                    .themeSecondary()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).themeTertiary()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .themeTertiary()
            }
            .padding(14)
            .background {
                AppTheme.continuousRect(AppTheme.cornerMedium)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
    }
}
