import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    @Query private var transactions: [MoneyTransaction]
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var name = ""
    @State private var currency: AppCurrency = .byn
    @State private var openingText = ""
    @State private var accountBudgetTexts: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    QuietSectionLabel(text: L10n.string("accounts.list"))
                    ForEach(accounts.filter { !$0.isArchived }, id: \.id) { account in
                        accountCard(account)
                    }

                    QuietSectionLabel(text: L10n.string("accounts.add"))
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(L10n.string("accounts.name"), text: $name)
                                .glassField()
                            Picker(L10n.string("field.currency"), selection: $currency) {
                                ForEach(AppCurrency.allCases) { code in
                                    Text(code.code).tag(code)
                                }
                            }
                            .pickerStyle(.segmented)
                            TextField(L10n.string("accounts.opening"), text: $openingText)
                                .keyboardType(.decimalPad)
                                .glassField()
                            Button(L10n.string("accounts.create")) { createAccount() }
                                .buttonStyle(.borderedProminent)
                                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    QuietSectionLabel(text: L10n.string("budget.accounts"))
                    Text(L10n.string("budget.accountsHint"))
                        .font(.footnote)
                        .themeTertiary()
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(accounts.filter { !$0.isArchived }, id: \.id) { account in
                                HStack {
                                    Text(account.name).font(.subheadline).lineLimit(1)
                                    Spacer()
                                    TextField(
                                        L10n.string("budget.amount"),
                                        text: Binding(
                                            get: { accountBudgetTexts[account.id] ?? "" },
                                            set: { newValue in
                                                accountBudgetTexts[account.id] = newValue
                                                let normalized = newValue
                                                    .replacingOccurrences(of: ",", with: ".")
                                                    .trimmingCharacters(in: .whitespaces)
                                                if normalized.isEmpty {
                                                    settings.setAccountBudget(nil, for: account.id)
                                                } else if let value = Double(normalized), value > 0 {
                                                    settings.setAccountBudget(value, for: account.id)
                                                }
                                            }
                                        )
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 110)
                                    .glassField()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, 16)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("accounts.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .onAppear {
                var texts: [String: String] = [:]
                for account in accounts {
                    if let limit = settings.accountBudget(for: account.id) {
                        texts[account.id] = String(format: "%g", limit)
                    }
                }
                accountBudgetTexts = texts
            }
        }
    }

    private func accountCard(_ account: MoneyAccount) -> some View {
        let native = AccountLedger.balance(account: account, transactions: transactions)
        let display = CurrencyConverter.convert(
            native,
            from: account.currency,
            to: currencySettings.displayCurrency
        )
        return GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
            HStack(spacing: 12) {
                Image(systemName: account.symbolName)
                    .font(.title3)
                    .themeSecondary()
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name).font(.subheadline.weight(.semibold))
                    Text(account.currency.code)
                        .font(.caption2)
                        .themeTertiary()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyFormat.currency(native, code: account.currency))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if account.currency != currencySettings.displayCurrency {
                        Text(MoneyFormat.currency(display, code: currencySettings.displayCurrency))
                            .font(.caption2)
                            .themeTertiary()
                    }
                }
            }
        }
    }

    private func createAccount() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let opening = Double(openingText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let account = MoneyAccount(
            name: trimmed,
            currency: currency,
            spaceId: SpaceIDs.privateDefault,
            sortOrder: (accounts.map(\.sortOrder).max() ?? 0) + 1,
            symbolName: currency == .byn ? "banknote" : "creditcard",
            openingBalance: opening
        )
        modelContext.insert(account)
        try? modelContext.save()
        name = ""
        openingText = ""
    }
}
