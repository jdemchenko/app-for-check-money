import SwiftUI
import SwiftData

struct AddTransactionView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case manual
        case voice
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var mode: Mode = .manual
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var categoryId: String?
    @State private var note = ""
    @State private var date = Date.now
    @State private var autoAssigned = false
    @State private var draft: VoiceDraft?
    @State private var showSavedToast = false
    @StateObject private var speech = SpeechRecognizer()

    private var availableCategories: [MoneyCategory] {
        CategoryMatcher.categories(for: type, in: categories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker(L10n.string("add.mode"), selection: $mode) {
                        Text(L10n.string("add.manual")).tag(Mode.manual)
                        Text(L10n.string("add.voice")).tag(Mode.voice)
                    }
                    .pickerStyle(.segmented)

                    if mode == .voice {
                        voiceCard
                    }

                    formCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.string("tab.add"))
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if categoryId == nil {
                    categoryId = availableCategories.first?.id
                }
                Task { await speech.prepare() }
            }
            .onChange(of: type) { _, _ in
                if let categoryId,
                   availableCategories.contains(where: { $0.id == categoryId }) {
                    return
                }
                categoryId = availableCategories.first?.id
                autoAssigned = false
            }
            .onChange(of: note) { _, newValue in
                guard mode == .manual else { return }
                guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    autoAssigned = false
                    return
                }
                if let match = CategoryMatcher.autoAssign(
                    text: newValue,
                    categories: categories,
                    preferredType: type
                ) {
                    categoryId = match.id
                    autoAssigned = true
                }
            }
            .onChange(of: speech.transcript) { _, text in
                guard !text.isEmpty else { return }
                let parsed = VoiceParser.parse(rawText: text, categories: categories)
                draft = parsed
                if let amount = parsed.amount {
                    amountText = String(format: "%g", amount)
                }
                if let parsedType = parsed.type {
                    type = parsedType
                }
                if let id = parsed.categoryId {
                    categoryId = id
                    autoAssigned = true
                }
                if !parsed.note.isEmpty {
                    note = parsed.note
                }
            }
            .alert(L10n.string("add.saved"), isPresented: $showSavedToast) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            }
        }
    }

    private var voiceCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                switch speech.status {
                case .unavailable(let message), .failed(let message):
                    Label(message, systemImage: "mic.slash.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                default:
                    Text(L10n.string("voice.hint"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button {
                        if speech.status == .listening {
                            speech.stop()
                        } else {
                            speech.start()
                        }
                    } label: {
                        Image(systemName: speech.status == .listening ? "mic.fill" : "mic")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                            .background(
                                Circle().fill(
                                    speech.status == .listening
                                        ? Color(hex: "FF3B30")
                                        : Color(hex: "0A84FF")
                                )
                            )
                            .shadow(
                                color: (speech.status == .listening
                                        ? Color(hex: "FF3B30")
                                        : Color(hex: "0A84FF")).opacity(0.35),
                                radius: 16,
                                y: 8
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        speech.status == .listening
                            ? L10n.string("voice.stop")
                            : L10n.string("voice.start")
                    )

                    Text(
                        speech.status == .listening
                            ? L10n.string("voice.listening")
                            : L10n.string("voice.tap")
                    )
                    .font(.subheadline.weight(.medium))

                    if !speech.transcript.isEmpty {
                        Text("“\(speech.transcript)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if draft != nil {
                        HStack {
                            Label(L10n.string("voice.draft"), systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "0A84FF"))
                            Spacer()
                            Button(L10n.string("voice.clear")) {
                                draft = nil
                                amountText = ""
                                note = ""
                                autoAssigned = false
                                speech.clearTranscript()
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var formCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.amount"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.type"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        typeButton(.expense, title: L10n.string("type.expense"))
                        typeButton(.income, title: L10n.string("type.income"))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.string("field.category"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        if autoAssigned {
                            Text(L10n.string("category.auto"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "0A84FF").opacity(0.14), in: Capsule())
                                .foregroundStyle(Color(hex: "0A84FF"))
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(availableCategories, id: \.id) { cat in
                            Button {
                                categoryId = cat.id
                                autoAssigned = false
                            } label: {
                                HStack(spacing: 8) {
                                    CategoryGlyph(
                                        symbolName: cat.symbolName,
                                        colorHex: cat.colorHex,
                                        size: 28
                                    )
                                    Text(cat.displayName())
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            categoryId == cat.id
                                                ? Color(hex: "0A84FF").opacity(0.12)
                                                : Color.primary.opacity(0.05)
                                        )
                                        .overlay {
                                            if categoryId == cat.id {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(Color(hex: "0A84FF").opacity(0.4), lineWidth: 1)
                                            }
                                        }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.note"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField(L10n.string("field.notePlaceholder"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }

                DatePicker(
                    L10n.string("field.date"),
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                Button {
                    save()
                } label: {
                    Text(mode == .voice ? L10n.string("common.confirm") : L10n.string("common.save"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "0A84FF"))
                .clipShape(Capsule())
            }
        }
    }

    private func typeButton(_ value: TransactionType, title: String) -> some View {
        Button {
            type = value
            autoAssigned = false
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            type == value
                                ? (value == .expense
                                    ? Color(hex: "FF3B30").opacity(0.15)
                                    : Color(hex: "34C759").opacity(0.15))
                                : Color.primary.opacity(0.05)
                        )
                )
                .foregroundStyle(
                    type == value
                        ? (value == .expense ? Color(hex: "FF3B30") : Color(hex: "34C759"))
                        : .secondary
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0 else { return }
        guard let categoryId else { return }

        let tx = MoneyTransaction(
            amount: (amount * 100).rounded() / 100,
            type: type,
            categoryId: categoryId,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            date: date,
            source: mode == .voice ? .voice : .manual
        )
        modelContext.insert(tx)
        try? modelContext.save()

        amountText = ""
        note = ""
        draft = nil
        autoAssigned = false
        speech.clearTranscript()
        showSavedToast = true
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
