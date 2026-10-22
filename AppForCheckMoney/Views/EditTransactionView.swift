import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @Bindable var transaction: MoneyTransaction

    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var categoryId: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var currency: AppCurrency = .byn
    @State private var paymentMethod: PaymentMethod = .unspecified

    private var availableCategories: [MoneyCategory] {
        CategoryMatcher.categories(for: type, in: categories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("field.amount"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.semibold).monospacedDigit())
                                .glassField()
                        }
                    }

                    Picker(L10n.string("field.type"), selection: $type) {
                        Text(L10n.string("type.expense")).tag(TransactionType.expense)
                        Text(L10n.string("type.income")).tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in
                        if !availableCategories.contains(where: { $0.id == categoryId }) {
                            categoryId = availableCategories.first?.id ?? categoryId
                        }
                    }

                    QuietSectionLabel(text: L10n.string("field.category"))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(availableCategories, id: \.id) { cat in
                            Button {
                                categoryId = cat.id
                            } label: {
                                HStack(spacing: 8) {
                                    CategoryGlyph(symbolName: cat.symbolName, colorHex: cat.colorHex, size: 26)
                                    Text(cat.displayName())
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .glassChip(selected: categoryId == cat.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("field.currency"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker(L10n.string("field.currency"), selection: $currency) {
                            ForEach(AppCurrency.allCases) { code in
                                Text(code.code).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("field.payment"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker(L10n.string("field.payment"), selection: $paymentMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.title).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("field.note"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField(L10n.string("field.notePlaceholder"), text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .glassField()
                    }

                    DatePicker(L10n.string("field.date"), selection: $date, displayedComponents: .date)

                    GlassActionButton(title: L10n.string("common.save")) {
                        save()
                    }
                    .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
                }
            }
            .onAppear {
                amountText = String(format: "%g", transaction.amount)
                type = transaction.type
                categoryId = transaction.categoryId
                note = transaction.note ?? ""
                date = transaction.date
                currency = transaction.currency
                paymentMethod = transaction.paymentMethod
            }
        }
    }

    private func save() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0 else { return }
        guard !categoryId.isEmpty else { return }
        transaction.amount = (amount * 100).rounded() / 100
        transaction.type = type
        transaction.categoryId = categoryId
        transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        transaction.date = date
        transaction.currency = currency
        transaction.paymentMethod = paymentMethod
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
