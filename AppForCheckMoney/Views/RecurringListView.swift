import SwiftUI
import SwiftData

struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringRule.nextFireDate) private var rules: [RecurringRule]
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if rules.isEmpty {
                    ContentUnavailableView(
                        L10n.string("recurring.empty"),
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text(L10n.string("recurring.emptyHint"))
                    )
                } else {
                    List {
                        ForEach(rules, id: \.id) { rule in
                            recurringRow(rule)
                                .listRowBackground(
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(.ultraThinMaterial)
                                        .padding(.vertical, 2)
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(rule)
                                        try? modelContext.save()
                                    } label: {
                                        Label(L10n.string("common.delete"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .liquidScreen()
            .navigationTitle(L10n.string("recurring.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.string("recurring.add"))
                }
            }
            .sheet(isPresented: $showCreate) {
                RecurringEditorSheet(categories: categories)
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                _ = RecurringEngine.applyDue(in: modelContext)
            }
        }
    }

    private func recurringRow(_ rule: RecurringRule) -> some View {
        let cat = categories.first { $0.id == rule.categoryId }
        return HStack(spacing: 12) {
            CategoryGlyph(
                symbolName: cat?.symbolName ?? "arrow.triangle.2.circlepath",
                colorHex: cat?.colorHex ?? "8E8E93",
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(cat?.displayName() ?? L10n.string("category.unknown"))
                    .font(.body.weight(.medium))
                Text(rule.frequency.title + " · " + rule.nextFireDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(MoneyFormat.signed(rule.amount, type: rule.type, code: rule.currency))
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Toggle("", isOn: Binding(
                get: { rule.isActive },
                set: {
                    rule.isActive = $0
                    try? modelContext.save()
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct RecurringEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let categories: [MoneyCategory]

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var categoryId: String = ""
    @State private var note = ""
    @State private var currency: AppCurrency = CurrencySettings.shared.entryCurrency
    @State private var paymentMethod: PaymentMethod = .unspecified
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextFire = Date.now

    private var available: [MoneyCategory] {
        CategoryMatcher.categories(for: type, in: categories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField(L10n.string("field.amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                        .glassField()

                    Picker(L10n.string("field.type"), selection: $type) {
                        Text(L10n.string("type.expense")).tag(TransactionType.expense)
                        Text(L10n.string("type.income")).tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in
                        categoryId = available.first?.id ?? ""
                    }

                    Picker(L10n.string("field.category"), selection: $categoryId) {
                        ForEach(available, id: \.id) { cat in
                            Text(cat.displayName()).tag(cat.id)
                        }
                    }

                    Picker(L10n.string("recurring.frequency"), selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker(L10n.string("recurring.next"), selection: $nextFire, displayedComponents: .date)

                    Picker(L10n.string("field.payment"), selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField(L10n.string("field.notePlaceholder"), text: $note)
                        .glassField()

                    GlassActionButton(title: L10n.string("common.save")) {
                        save()
                    }
                    .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil || categoryId.isEmpty)
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("recurring.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
                }
            }
            .onAppear {
                if categoryId.isEmpty {
                    categoryId = available.first?.id ?? ""
                }
            }
        }
    }

    private func save() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0, !categoryId.isEmpty else { return }
        let rule = RecurringRule(
            amount: (amount * 100).rounded() / 100,
            type: type,
            categoryId: categoryId,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            currency: currency,
            paymentMethod: paymentMethod,
            frequency: frequency,
            nextFireDate: Calendar.current.startOfDay(for: nextFire)
        )
        modelContext.insert(rule)
        try? modelContext.save()
        _ = RecurringEngine.applyDue(in: modelContext)
        PhoneWatchSync.shared.pushSnapshot()
        dismiss()
    }
}
