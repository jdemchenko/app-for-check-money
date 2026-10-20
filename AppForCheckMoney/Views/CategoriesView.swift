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
            List {
                if !defaults.isEmpty {
                    Section(L10n.string("categories.defaults")) {
                        ForEach(defaults, id: \.id) { cat in
                            categoryRow(cat)
                                .contentShape(Rectangle())
                                .onTapGesture { editor = .edit(cat) }
                        }
                    }
                }

                Section(L10n.string("categories.custom")) {
                    if custom.isEmpty {
                        Text(L10n.string("categories.customEmpty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(custom, id: \.id) { cat in
                            categoryRow(cat)
                                .contentShape(Rectangle())
                                .onTapGesture { editor = .edit(cat) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(cat)
                                        try? modelContext.save()
                                    } label: {
                                        Label(L10n.string("common.delete"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.string("tab.categories"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRestoreConfirm = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel(L10n.string("categories.restore"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.string("categories.add"))
                }
            }
            .sheet(item: $editor) { state in
                CategoryEditorSheet(state: state)
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

    private func categoryRow(_ cat: MoneyCategory) -> some View {
        HStack(spacing: 12) {
            CategoryGlyph(symbolName: cat.symbolName, colorHex: cat.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.displayName())
                    .font(.body.weight(.medium))
                Text(cat.keywords.prefix(4).joined(separator: ", ").nilIfEmpty ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string("categories.nameRu"), text: $nameRu)
                    TextField(L10n.string("categories.nameEn"), text: $nameEn)
                }
                Section(L10n.string("field.type")) {
                    Picker(L10n.string("field.type"), selection: $kind) {
                        Text(L10n.string("type.expense")).tag(CategoryKind.expense)
                        Text(L10n.string("type.income")).tag(CategoryKind.income)
                        Text(L10n.string("type.both")).tag(CategoryKind.both)
                    }
                    .pickerStyle(.segmented)
                }
                Section(L10n.string("categories.keywords")) {
                    TextField(L10n.string("categories.keywordsHint"), text: $keywordsText, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    TextField(L10n.string("categories.colorHex"), text: $colorHex)
                    TextField(L10n.string("categories.symbol"), text: $symbolName)
                    HStack {
                        Spacer()
                        CategoryGlyph(symbolName: symbolName, colorHex: colorHex, size: 56)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) { save() }
                        .disabled(nameRu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        if case .edit(let cat) = state {
            nameRu = cat.nameRu
            nameEn = cat.nameEn
            kind = cat.kind
            keywordsText = cat.keywords.joined(separator: ", ")
            colorHex = cat.colorHex
            symbolName = cat.symbolName
        }
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
