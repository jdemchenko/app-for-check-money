import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var editor: EditorState?
    @State private var showRestoreConfirm = false

    private var defaults: [MoneyCategory] { categories.filter(\.isDefault) }
    private var custom: [MoneyCategory] { categories.filter { !$0.isDefault } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spaceSection) {
                    if !defaults.isEmpty {
                        categorySection(
                            title: L10n.string("categories.defaults"),
                            items: defaults,
                            canDelete: false
                        )
                    }
                    categorySection(
                        title: L10n.string("categories.custom"),
                        items: custom,
                        canDelete: true,
                        emptyText: L10n.string("categories.customEmpty")
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
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
            .sheet(item: $editor) { state in
                CategoryEditorSheet(state: state)
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
                }
                Button(L10n.string("common.cancel"), role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func categorySection(
        title: String,
        items: [MoneyCategory],
        canDelete: Bool,
        emptyText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: title)

            GlassPanel(padding: 6, corner: AppTheme.cornerMedium) {
                if items.isEmpty, let emptyText {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(items, id: \.id) { cat in
                            Button {
                                editor = .edit(cat)
                            } label: {
                                categoryRow(cat)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if canDelete {
                                    Button(role: .destructive) {
                                        modelContext.delete(cat)
                                        try? modelContext.save()
                                    } label: {
                                        Label(L10n.string("common.delete"), systemImage: "trash")
                                    }
                                }
                            }

                            if cat.id != items.last?.id {
                                Divider().opacity(0.25).padding(.leading, 54)
                            }
                        }
                    }
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

    @State private var nameRu = ""
    @State private var nameEn = ""
    @State private var kind: CategoryKind = .expense
    @State private var keywordsText = ""
    @State private var colorHex = "0A84FF"
    @State private var symbolName = "circle.fill"

    /// Once the user edits keywords by hand, stop overwriting — unless the field still equals the last auto-fill.
    @State private var keywordsUserEdited = false
    @State private var lastAutoKeywords = ""
    @State private var suppressKeywordsTracking = false
    @State private var suggestTask: Task<Void, Never>?

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
                        VStack(spacing: 12) {
                            HStack {
                                TextField(L10n.string("categories.colorHex"), text: $colorHex)
                                    .glassField()
                                TextField(L10n.string("categories.symbol"), text: $symbolName)
                                    .glassField()
                            }
                            CategoryGlyph(symbolName: symbolName, colorHex: colorHex, size: 56)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    GlassActionButton(title: L10n.string("common.save")) {
                        save()
                    }
                    .disabled(nameRu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(
                        nameRu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1
                    )
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
            .onChange(of: nameRu) { _, _ in scheduleKeywordSuggest() }
            .onChange(of: nameEn) { _, _ in scheduleKeywordSuggest() }
            .onChange(of: symbolName) { _, _ in scheduleKeywordSuggest() }
            .onChange(of: kind) { _, _ in scheduleKeywordSuggest() }
            .onChange(of: keywordsText) { _, _ in
                guard !suppressKeywordsTracking else { return }
                keywordsUserEdited = true
            }
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
                .onSubmit { applyKeywordSuggest(immediate: true) }
        }
    }

    private func load() {
        if case .edit(let cat) = state {
            nameRu = cat.nameRu
            nameEn = cat.nameEn
            kind = cat.kind
            suppressKeywordsTracking = true
            keywordsText = cat.keywords.joined(separator: ", ")
            lastAutoKeywords = keywordsText
            suppressKeywordsTracking = false
            // Preserve saved keywords until the user clears them or they still match auto-fill.
            keywordsUserEdited = !cat.keywords.isEmpty
            colorHex = cat.colorHex
            symbolName = cat.symbolName
        } else {
            keywordsUserEdited = false
            lastAutoKeywords = ""
        }
        if keywordsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applyKeywordSuggest(immediate: true)
        }
    }

    private func scheduleKeywordSuggest() {
        suggestTask?.cancel()
        suggestTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            applyKeywordSuggest(immediate: false)
        }
    }

    private func applyKeywordSuggest(immediate: Bool) {
        if immediate {
            suggestTask?.cancel()
        }
        let csv = KeywordSuggester.suggestCSV(
            nameRu: nameRu,
            nameEn: nameEn,
            symbolName: symbolName,
            kind: kind
        )
        guard !csv.isEmpty else { return }

        let canReplace =
            !keywordsUserEdited
            || keywordsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || keywordsText == lastAutoKeywords

        guard canReplace else { return }

        suppressKeywordsTracking = true
        keywordsText = csv
        lastAutoKeywords = csv
        suppressKeywordsTracking = false
        keywordsUserEdited = false
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
                colorHex: hex.isEmpty ? "0A84FF" : hex,
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
            cat.colorHex = hex.isEmpty ? "0A84FF" : hex
            cat.symbolName = symbolName.isEmpty ? "circle.fill" : symbolName
        }
        try? modelContext.save()
        dismiss()
    }
}
