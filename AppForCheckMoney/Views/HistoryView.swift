import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyTransaction.date, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @State private var query = ""
    @State private var typeFilter: TypeFilter = .all
    @State private var categoryFilter: String = "all"
    @State private var paymentFilter: PaymentFilter = .all
    @State private var fromDate: Date?
    @State private var toDate: Date?
    @State private var showFilters = false
    @State private var selected: MoneyTransaction?
    @State private var editing: MoneyTransaction?
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var exportError: String?
    @State private var pendingDelete: MoneyTransaction?
    @ObservedObject private var currencySettings = CurrencySettings.shared

    enum TypeFilter: String, CaseIterable, Identifiable {
        case all, expense, income
        var id: String { rawValue }
    }

    enum PaymentFilter: String, CaseIterable, Identifiable {
        case all, cash, card, unspecified
        var id: String { rawValue }
    }

    private var filtered: [MoneyTransaction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return transactions.filter { tx in
            if typeFilter == .expense, tx.type != .expense { return false }
            if typeFilter == .income, tx.type != .income { return false }
            if categoryFilter != "all", tx.categoryId != categoryFilter { return false }
            switch paymentFilter {
            case .all: break
            case .cash: if tx.paymentMethod != .cash { return false }
            case .card: if tx.paymentMethod != .card { return false }
            case .unspecified: if tx.paymentMethod != .unspecified { return false }
            }
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
                let hay = "\(tx.note ?? "") \(cat?.displayName() ?? "") \(tx.amount) \(tx.currency.code) \(tx.paymentMethod.title)".lowercased()
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
                    List {
                        ForEach(grouped, id: \.day) { group in
                            Section {
                                ForEach(group.items, id: \.id) { tx in
                                    Button {
                                        selected = tx
                                    } label: {
                                        TransactionRowView(
                                            transaction: tx,
                                            category: categories.first { $0.id == tx.categoryId },
                                            displayCurrency: currencySettings.displayCurrency
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(
                                        AppTheme.continuousRect(AppTheme.radiusControl)
                                            .fill(.ultraThinMaterial)
                                            .padding(.vertical, 2)
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            pendingDelete = tx
                                        } label: {
                                            Label(L10n.string("common.delete"), systemImage: "trash")
                                        }
                                        .tint(AppTheme.expense)
                                    }
                                }
                            } header: {
                                dayHeader(group.day, items: group.items)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .liquidScreen()
            .navigationTitle(L10n.string("tab.history"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: L10n.string("history.search"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        exportCSV()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.string("export.share"))
                    .disabled(filtered.isEmpty)

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
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editing) { tx in
                EditTransactionView(transaction: tx)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .alert(
                L10n.string("export.share"),
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button(L10n.string("common.ok"), role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .overlay {
                if pendingDelete != nil {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture { pendingDelete = nil }
                        QuietConfirmPanel(
                            title: L10n.string("history.deleteConfirm"),
                            message: L10n.string("history.deleteHint"),
                            confirmTitle: L10n.string("common.delete"),
                            confirmDestructive: true,
                            onConfirm: { confirmPendingDelete() },
                            onCancel: { pendingDelete = nil }
                        )
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.2), value: pendingDelete?.id)
        }
    }

    private func confirmPendingDelete() {
        guard let tx = pendingDelete else { return }
        modelContext.delete(tx)
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        if selected?.id == tx.id { selected = nil }
        pendingDelete = nil
    }

    private func exportCSV() {
        guard !filtered.isEmpty else {
            exportError = L10n.string("export.empty")
            return
        }
        let csv = CSVExport.makeCSV(
            transactions: filtered,
            categories: categories,
            from: fromDate,
            to: toDate
        )
        do {
            exportURL = try CSVExport.writeTempFile(csv: csv)
            showShare = true
        } catch {
            exportError = L10n.string("export.failed")
        }
    }

    private func dayHeader(_ day: Date, items: [MoneyTransaction]) -> some View {
        let daySpend = items
            .filter { $0.type == .expense }
            .reduce(0.0) { $0 + $1.amountIn(currencySettings.displayCurrency) }
        return HStack {
            Text(MoneyFormat.dayLabel(day))
            Spacer(minLength: 8)
            if daySpend > 0 {
                Text("−" + MoneyFormat.currency(daySpend, code: currencySettings.displayCurrency))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(nil)
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

                    QuietSectionLabel(text: L10n.string("field.payment"))
                    Picker(L10n.string("field.payment"), selection: $paymentFilter) {
                        Text(L10n.string("filter.all")).tag(PaymentFilter.all)
                        Text(L10n.string("payment.cash")).tag(PaymentFilter.cash)
                        Text(L10n.string("payment.card")).tag(PaymentFilter.card)
                        Text(L10n.string("payment.unspecified")).tag(PaymentFilter.unspecified)
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
                        paymentFilter = .all
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
                    if tx.paymentMethod != .unspecified {
                        Text(L10n.string("field.payment") + ": " + tx.paymentMethod.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                    GlassActionButton(title: L10n.string("common.edit"), systemImage: "pencil") {
                        editing = tx
                        selected = nil
                    }
                    GlassActionButton(
                        title: L10n.string("common.delete"),
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        // Dismiss detail first so the quiet glass confirm isn’t buried under the sheet.
                        selected = nil
                        pendingDelete = tx
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

/// UIKit share wrapper for CSV export.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
