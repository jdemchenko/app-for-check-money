import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var editor: EditorState?
    @State private var showRestoreConfirm = false
    @State private var pendingDelete: MoneyCategory?
    @State private var pendingDeleteCount = 0
    /// Set from the editor; confirmed after the sheet dismisses.
    @State private var deleteAfterDismiss: MoneyCategory?

    private var defaults: [MoneyCategory] { categories.filter(\.isDefault) }
    private var custom: [MoneyCategory] { categories.filter { !$0.isDefault } }

    var body: some View {
        NavigationStack {
            List {
                if !defaults.isEmpty {
                    Section {
                        ForEach(defaults, id: \.id) { cat in
                            categoryButton(cat, canDelete: false)
                        }
                    } header: {
                        Text(L10n.string("categories.defaults"))
                    }
                }

                Section {
                    if custom.isEmpty {
                        Text(L10n.string("categories.customEmpty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(custom, id: \.id) { cat in
                            categoryButton(cat, canDelete: true)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        requestDelete(cat)
                                    } label: {
                                        Label(L10n.string("common.delete"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    Text(L10n.string("categories.custom"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .liquidScreen()
            .navigationTitle(L10n.string("tab.categories"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editor = .create
                        } label: {
                            Label(L10n.string("categories.add"), systemImage: "plus")
                        }
                        Button(role: .destructive) {
                            showRestoreConfirm = true
                        } label: {
                            Label(L10n.string("categories.restore"), systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editor, onDismiss: {
                if let cat = deleteAfterDismiss {
                    deleteAfterDismiss = nil
                    requestDelete(cat)
                }
            }) { state in
                CategoryEditorSheet(
                    state: state,
                    onRequestDelete: { cat in
                        deleteAfterDismiss = cat
                        editor = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                L10n.string("categories.restore"),
                isPresented: $showRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.string("categories.restore"), role: .destructive) {
                    SeedData.restoreDefaults(in: modelContext)
                    PhoneWatchSync.shared.pushSnapshot()
                }
                Button(L10n.string("common.cancel"), role: .cancel) {}
            }
            .confirmationDialog(
                pendingDelete.map { String(format: L10n.string("categories.deleteConfirm"), $0.displayName()) }
                    ?? L10n.string("categories.delete"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.string("categories.delete"), role: .destructive) {
                    confirmPendingDelete()
                }
                Button(L10n.string("common.cancel"), role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteMessage: String {
        if pendingDeleteCount > 0 {
            return String(format: L10n.string("categories.deleteReassignCount"), pendingDeleteCount)
        }
        return L10n.string("categories.deleteReassign")
    }

    private func categoryButton(_ cat: MoneyCategory, canDelete: Bool) -> some View {
        Button {
            editor = .edit(cat)
        } label: {
            categoryRow(cat)
        }
        .buttonStyle(.plain)
        .listRowBackground(ListRowGlassBackground())
        .contextMenu {
            if canDelete {
                Button(role: .destructive) {
                    requestDelete(cat)
                } label: {
                    Label(L10n.string("common.delete"), systemImage: "trash")
                }
            }
        }
    }

    private func categoryRow(_ cat: MoneyCategory) -> some View {
        HStack(spacing: 12) {
            CategoryGlyph(symbolName: cat.symbolName, colorHex: cat.colorHex, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.displayName())
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(cat.keywords.prefix(3).joined(separator: ", ").nilIfEmpty ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func requestDelete(_ cat: MoneyCategory) {
        guard !cat.isDefault else { return }
        pendingDeleteCount = SeedData.transactionCount(forCategoryId: cat.id, in: modelContext)
        pendingDelete = cat
    }

    private func confirmPendingDelete() {
        guard let cat = pendingDelete else { return }
        pendingDelete = nil
        _ = SeedData.deleteUserCategory(cat, in: modelContext)
        PhoneWatchSync.shared.pushSnapshot()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum EditorState: Identifiable {
    case create
    case edit(MoneyCategory)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let cat): return cat.id
        }
    }
}

struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let state: EditorState
    var onRequestDelete: ((MoneyCategory) -> Void)?

    @State private var nameRu = ""
    @State private var nameEn = ""
    @State private var kind: CategoryKind = .expense
    @State private var keywordsText = ""
    @State private var colorHex = "8E8E93"
    @State private var symbolName = "circle.fill"
    @State private var symbolSuggestions: [String] = []

    /// Track last auto-fill; treat field as user-edited only when it diverges.
    @State private var lastAutoKeywords = ""
    @State private var suggestTask: Task<Void, Never>?
    @State private var symbolLocked = false

    private var editingCustom: MoneyCategory? {
        if case .edit(let cat) = state, !cat.isDefault { return cat }
        return nil
    }

    private var keywordsAreAutoSynced: Bool {
        let trimmed = keywordsText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == lastAutoKeywords
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            field(L10n.string("categories.nameRu"), text: $nameRu)
                            field(L10n.string("categories.nameEn"), text: $nameEn)
                        }
                    }

                    QuietSectionLabel(text: L10n.string("field.type"))
                    Picker(L10n.string("field.type"), selection: $kind) {
                        Text(L10n.string("type.expense")).tag(CategoryKind.expense)
                        Text(L10n.string("type.income")).tag(CategoryKind.income)
                        Text(L10n.string("type.both")).tag(CategoryKind.both)
                    }
                    .pickerStyle(.segmented)

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("categories.keywords"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField(L10n.string("categories.keywordsHint"), text: $keywordsText, axis: .vertical)
                                .lineLimit(2...6)
                            Text(L10n.string("categories.keywordsAuto"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TextField(L10n.string("categories.colorHex"), text: $colorHex)
                                    .glassField()
                                TextField(L10n.string("categories.symbol"), text: $symbolName)
                                    .glassField()
                                    .onSubmit { symbolLocked = true }
                            }
                            CategoryGlyph(symbolName: symbolName, colorHex: colorHex, size: 56)
                                .frame(maxWidth: .infinity)

                            if !symbolSuggestions.isEmpty {
                                Text(L10n.string("categories.symbolSuggest"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(symbolSuggestions, id: \.self) { symbol in
                                            Button {
                                                symbolName = symbol
                                                symbolLocked = true
                                            } label: {
                                                Image(systemName: symbol)
                                                    .font(.body.weight(.medium))
                                                    .foregroundStyle(
                                                        symbolName == symbol ? Color.primary : Color.secondary
                                                    )
                                                    .frame(width: 40, height: 40)
                                                    .background {
                                                        Circle()
                                                            .fill(.thinMaterial)
                                                            .overlay {
                                                                Circle()
                                                                    .strokeBorder(
                                                                        symbolName == symbol
                                                                            ? Color.primary.opacity(0.35)
                                                                            : Color.primary.opacity(0.08),
                                                                        lineWidth: 0.8
                                                                    )
                                                            }
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(symbol)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    GlassActionButton(title: L10n.string("common.save")) {
                        save()
                    }
                    .disabled(nameRu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(
                        nameRu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1
                    )

                    if let cat = editingCustom {
                        Button(role: .destructive) {
                            onRequestDelete?(cat)
                        } label: {
                            Text(L10n.string("categories.delete"))
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(
                {
                    switch state {
                    case .create: return L10n.string("categories.add")
                    case .edit: return L10n.string("common.edit")
                    }
                }()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
                }
            }
            .onAppear { load() }
            .onChange(of: nameRu) { _, _ in scheduleSuggest() }
            .onChange(of: nameEn) { _, _ in scheduleSuggest() }
            .onChange(of: kind) { _, _ in scheduleSuggest() }
            .onDisappear { suggestTask?.cancel() }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .glassField()
                .onSubmit { applySuggest(immediate: true) }
        }
    }

    private func load() {
        if case .edit(let cat) = state {
            nameRu = cat.nameRu
            nameEn = cat.nameEn
            kind = cat.kind
            keywordsText = cat.keywords.joined(separator: ", ")
            lastAutoKeywords = keywordsText
            colorHex = cat.colorHex
            symbolName = cat.symbolName
            symbolLocked = true
        } else {
            lastAutoKeywords = ""
            symbolLocked = false
        }
        refreshSymbolSuggestions()
        if keywordsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applySuggest(immediate: true)
        }
    }

    private func scheduleSuggest() {
        suggestTask?.cancel()
        suggestTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            applySuggest(immediate: false)
        }
    }

    private func applySuggest(immediate: Bool) {
        if immediate {
            suggestTask?.cancel()
        }
        refreshSymbolSuggestions()

        let csv = KeywordSuggester.suggestCSV(
            nameRu: nameRu,
            nameEn: nameEn,
            symbolName: symbolName,
            kind: kind
        )
        if !csv.isEmpty, keywordsAreAutoSynced {
            // Compare-to-lastAuto avoids the SwiftUI onChange race that used to lock keywords.
            keywordsText = csv
            lastAutoKeywords = csv
        }

        if !symbolLocked, let first = symbolSuggestions.first {
            symbolName = first
        }
    }

    private func refreshSymbolSuggestions() {
        symbolSuggestions = SymbolSuggester.suggest(nameRu: nameRu, nameEn: nameEn)
    }

    private func save() {
        let ru = nameRu.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = keywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        switch state {
        case .create:
            let cat = MoneyCategory(
                nameRu: ru,
                nameEn: en.isEmpty ? ru : en,
                kind: kind,
                keywords: keywords,
                colorHex: hex.isEmpty ? "8E8E93" : hex,
                symbolName: symbolName.isEmpty ? "circle.fill" : symbolName,
                isDefault: false,
                sortOrder: 1000
            )
            modelContext.insert(cat)
        case .edit(let cat):
            cat.nameRu = ru
            cat.nameEn = en.isEmpty ? ru : en
            cat.kind = kind
            cat.keywords = keywords
            cat.colorHex = hex.isEmpty ? "8E8E93" : hex
            cat.symbolName = symbolName.isEmpty ? "circle.fill" : symbolName
        }
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        dismiss()
    }
}
