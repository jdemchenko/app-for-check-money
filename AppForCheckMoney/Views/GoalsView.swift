import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyGoal.createdAt, order: .reverse) private var goals: [MoneyGoal]
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    @Query private var transactions: [MoneyTransaction]

    @State private var name = ""
    @State private var targetText = ""
    @State private var accountId: String = AccountIDs.cashBYN

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(goals, id: \.id) { goal in
                        goalCard(goal)
                    }

                    QuietSectionLabel(text: L10n.string("goals.add"))
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(L10n.string("goals.name"), text: $name)
                                .glassField()
                            TextField(L10n.string("goals.target"), text: $targetText)
                                .keyboardType(.decimalPad)
                                .glassField()
                            Picker(L10n.string("accounts.title"), selection: $accountId) {
                                ForEach(accounts.filter { !$0.isArchived }, id: \.id) { account in
                                    Text("\(account.name) · \(account.currency.code)").tag(account.id)
                                }
                            }
                            Button(L10n.string("goals.create")) { createGoal() }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    name.trimmingCharacters(in: .whitespaces).isEmpty
                                        || (Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
                                )
                        }
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("goals.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .onAppear {
                if accounts.contains(where: { $0.id == AccountIDs.cashBYN }) {
                    accountId = AccountIDs.cashBYN
                } else if let first = accounts.first {
                    accountId = first.id
                }
            }
        }
    }

    private func goalCard(_ goal: MoneyGoal) -> some View {
        let progress = AccountLedger.goalProgress(
            goal: goal,
            accounts: accounts,
            transactions: transactions
        )
        return GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: progress.ratio)
                    .tint(.primary)
                HStack {
                    Text(MoneyFormat.currency(progress.current, code: goal.currency))
                    Text("/")
                    Text(MoneyFormat.currency(goal.targetAmount, code: goal.currency))
                    Spacer()
                    Text("\(Int((progress.ratio * 100).rounded()))%")
                        .themeTertiary()
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                if !goal.isCompleted, progress.ratio >= 1 {
                    Button(L10n.string("goals.markDone")) {
                        goal.isCompleted = true
                        try? modelContext.save()
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func createGoal() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let target = Double(targetText.replacingOccurrences(of: ",", with: ".")), target > 0,
              !trimmed.isEmpty
        else { return }
        let currency = accounts.first { $0.id == accountId }?.currency ?? .byn
        modelContext.insert(MoneyGoal(
            name: trimmed,
            accountId: accountId,
            targetAmount: target,
            currency: currency
        ))
        try? modelContext.save()
        name = ""
        targetText = ""
    }
}
