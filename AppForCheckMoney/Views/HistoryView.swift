import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyTransaction.date, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @State private var query = ""
    @State private var typeFilter: TypeFilter = .all
    @State private var categoryFilter: String = "all"
    @State private var fromDate: Date?
    @State private var toDate: Date?
    @State private var showFilters = false
    @State private var selected: MoneyTransaction?
    @ObservedObject private var currencySettings = CurrencySettings.shared

    enum TypeFilter: String, CaseIterable, Identifiable {
        case all, expense, income
        var id: String { rawValue }
    }

    private var filtered: [MoneyTransaction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return transactions.filter { tx in
            if typeFilter == .expense, tx.type != .expense { return false }
            if typeFilter == .income, tx.type != .income { return false }
            if categoryFilter != "all", tx.categoryId != categoryFilter { return false }
            if let fromDate {
                let start = Calendar.current.startOfDay(for: fromDate)
                if tx.date < start { return false }
            }
            if let toDate {
                let end = Calendar.current.date(
                    bySettingHour: 23, minute: 59, second: 59, of: toDate
                ) ?? toDate
                if tx.date > end { return false }
            }
            if !q.isEmpty {
                let cat = categories.first { $0.id == tx.categoryId }
                let hay = "\(tx.note ?? "") \(cat?.displayName() ?? "") \(tx.amount) \(tx.currency.code) \(tx.currency.displaySymbol)".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
        .sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.createdAt > $1.createdAt
            }
            return $0.date > $1.date
        }
    }

    private var grouped: [(day: Date, items: [MoneyTransaction])] {
        let cal = Calendar.current
        var map: [Date: [MoneyTransaction]] = [:]
        for tx in filtered {
            let day = cal.startOfDay(for: tx.date)
            map[day, default: []].append(tx)
        }
        return map.keys.sorted(by: >).map { day in
            (day, map[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if grouped.isEmpty {
                    ContentUnavailableView(
                        L10n.string("history.empty"),
                        systemImage: "magnifyingglass",
                        description: Text(L10n.string("history.emptyHint"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22, pinnedViews: []) {
                            ForEach(grouped, id: \.day) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    QuietSectionLabel(text: MoneyFormat.dayLabel(group.day))
                                        .padding(.horizontal, 4)

                                    GlassPanel(padding: 6, corner: AppTheme.cornerMedium) {
                                        LazyVStack(spacing: 0) {
                                            ForEach(group.items, id: \.id) { tx in
                                                Button {
                                                    selected = tx
                                                } label: {
                                                    TransactionRowView(
                                                        transaction: tx,
                                                        category: categories.first { $0.id == tx.categoryId },
                                                        displayCurrency: currencySettings.displayCurrency
                                                    )
                                                    .padding(.horizontal, 10)
                                                }
                                                .buttonStyle(.plain)

                                                if tx.id != group.items.last?.id {
                                                    Divider().opacity(0.25).padding(.leading, 54)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .liquidScreen()
            .navigationTitle(L10n.string("tab.history"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: L10n.string("history.search"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(L10n.string("history.filters"))
                }
            }
            .sheet(isPresented: $showFilters) {
                filtersSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selected) { tx in
                transactionDetail(tx)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var filtersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    QuietSectionLabel(text: L10n.string("field.type"))
                    Picker(L10n.string("field.type"), selection: $typeFilter) {
                        Text(L10n.string("filter.all")).tag(TypeFilter.all)
                        Text(L10n.string("type.expense")).tag(TypeFilter.expense)
                        Text(L10n.string("type.income")).tag(TypeFilter.income)
                    }
                    .pickerStyle(.segmented)

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("field.category"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Picker(L10n.string("field.category"), selection: $categoryFilter) {
                                Text(L10n.string("filter.all")).tag("all")
                                ForEach(categories, id: \.id) { cat in
                                    Text(cat.displayName()).tag(cat.id)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            QuietSectionLabel(text: L10n.string("history.dateRange"))
                            Toggle(isOn: Binding(
                                get: { fromDate != nil },
                                set: { fromDate = $0 ? (fromDate ?? Date.now) : nil }
                            )) {
                                Text(L10n.string("history.useFrom"))
                            }
                            if fromDate != nil {
                                DatePicker(
                                    L10n.string("history.from"),
                                    selection: Binding(
                                        get: { fromDate ?? Date.now },
                                        set: { fromDate = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                            }
                            Toggle(isOn: Binding(
                                get: { toDate != nil },
                                set: { toDate = $0 ? (toDate ?? Date.now) : nil }
                            )) {
                                Text(L10n.string("history.useTo"))
                            }
                            if toDate != nil {
                                DatePicker(
                                    L10n.string("history.to"),
                                    selection: Binding(
                                        get: { toDate ?? Date.now },
                                        set: { toDate = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                            }
                        }
                    }

                    GlassActionButton(title: L10n.string("common.confirm")) {
                        showFilters = false
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("history.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("history.reset")) {
                        typeFilter = .all
                        categoryFilter = "all"
                        fromDate = nil
                        toDate = nil
                        query = ""
                    }
                }
            }
        }
    }

    private func transactionDetail(_ tx: MoneyTransaction) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            TransactionRowView(
                                transaction: tx,
                                category: categories.first { $0.id == tx.categoryId },
                                displayCurrency: currencySettings.displayCurrency
                            )
                            Text(L10n.string("field.currency") + ": " + tx.currency.code)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let note = tx.note, !note.isEmpty {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.string("field.note"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(note)
                                    .font(.body)
                            }
                        }
                    }
                    GlassActionButton(
                        title: L10n.string("common.delete"),
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        modelContext.delete(tx)
                        try? modelContext.save()
                        selected = nil
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("history.detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) { selected = nil }
                }
            }
        }
    }
}

extension MoneyTransaction: Identifiable {}
