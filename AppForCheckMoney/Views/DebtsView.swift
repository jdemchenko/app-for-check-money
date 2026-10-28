import SwiftUI
import SwiftData

struct DebtsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyDebt.createdAt, order: .reverse) private var debts: [MoneyDebt]

    @State private var person = ""
    @State private var amountText = ""
    @State private var direction: DebtDirection = .iOwe
    @State private var currency: AppCurrency = .byn
    @State private var note = ""
    @State private var showSettled = false

    private var visible: [MoneyDebt] {
        debts.filter { showSettled || !$0.isSettled }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle(L10n.string("debt.showSettled"), isOn: $showSettled)
                        .font(.subheadline)

                    ForEach(visible, id: \.id) { debt in
                        debtCard(debt)
                    }

                    QuietSectionLabel(text: L10n.string("debt.add"))
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(L10n.string("debt.person"), text: $person)
                                .glassField()
                            TextField(L10n.string("debt.amount"), text: $amountText)
                                .keyboardType(.decimalPad)
                                .glassField()
                            Picker(L10n.string("debt.direction"), selection: $direction) {
                                ForEach(DebtDirection.allCases) { d in
                                    Text(d.title).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                            Picker(L10n.string("field.currency"), selection: $currency) {
                                ForEach(AppCurrency.allCases) { code in
                                    Text(code.code).tag(code)
                                }
                            }
                            .pickerStyle(.segmented)
                            TextField(L10n.string("field.note"), text: $note)
                                .glassField()
                            Button(L10n.string("debt.create")) { createDebt() }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    person.trimmingCharacters(in: .whitespaces).isEmpty
                                        || (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
                                )
                        }
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("debt.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
        }
    }

    private func debtCard(_ debt: MoneyDebt) -> some View {
        GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.personName).font(.subheadline.weight(.semibold))
                        Text(debt.direction.title)
                            .font(.caption2)
                            .themeTertiary()
                    }
                    Spacer()
                    Text(MoneyFormat.currency(debt.amount, code: debt.currency))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if let note = debt.note, !note.isEmpty {
                    Text(note).font(.caption).themeSecondary()
                }
                if debt.isSettled {
                    Text(L10n.string("debt.settled"))
                        .font(.caption.weight(.medium))
                        .themeTertiary()
                } else {
                    Button(L10n.string("debt.settle")) {
                        debt.settle()
                        try? modelContext.save()
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .opacity(debt.isSettled ? 0.55 : 1)
        }
    }

    private func createDebt() {
        let who = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0, !who.isEmpty
        else { return }
        modelContext.insert(MoneyDebt(
            personName: who,
            amount: amount,
            currency: currency,
            direction: direction,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        try? modelContext.save()
        person = ""
        amountText = ""
        note = ""
    }
}
