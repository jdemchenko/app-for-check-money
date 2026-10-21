import SwiftUI
import SwiftData

struct AddTransactionView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case manual
        case voice
        var id: String { rawValue }
    }

    /// When true, presented from Home sheet — hide duplicate large chrome.
    var embeddedInSheet: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var mode: Mode = .manual
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var categoryId: String?
    @State private var note = ""
    @State private var date = Date.now
    @State private var autoAssigned = false
    @State private var draft: VoiceDraft?
    @State private var isHoldingMic = false
    @State private var entryCurrency: AppCurrency = CurrencySettings.shared.entryCurrency
    @State private var paymentMethod: PaymentMethod = .unspecified
    @StateObject private var speech = SpeechRecognizer()
    @ObservedObject private var currencySettings = CurrencySettings.shared

    private var availableCategories: [MoneyCategory] {
        CategoryMatcher.categories(for: type, in: categories)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker(L10n.string("add.mode"), selection: $mode) {
                    Text(L10n.string("add.manual")).tag(Mode.manual)
                    Text(L10n.string("add.voice")).tag(Mode.voice)
                }
                .pickerStyle(.segmented)

                if mode == .voice {
                    voiceBlock
                }

                formBlock
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .liquidScreen()
        .navigationTitle(L10n.string("tab.add"))
        .navigationBarTitleDisplayMode(embeddedInSheet ? .inline : .large)
        .toolbar {
            if embeddedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(
                    mode == .voice
                        ? L10n.string("common.confirm")
                        : L10n.string("common.save")
                ) {
                    save()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            speech.allowsSilenceFinish = false
            entryCurrency = currencySettings.entryCurrency
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
            if let currency = parsed.currency {
                entryCurrency = currency
            }
        }
    }

    private var voiceBlock: some View {
        GlassPanel {
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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(L10n.string("home.quickEntryHint"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 84, height: 84)
                            .overlay {
                                Circle().fill(Color.primary.opacity(speech.isListening ? 0.12 : 0.06))
                            }
                            .overlay {
                                Circle().strokeBorder(AppTheme.glassStroke(colorScheme), lineWidth: 1)
                            }
                        Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !isHoldingMic else { return }
                                isHoldingMic = true
                                if !speech.isListening { speech.start() }
                            }
                            .onEnded { _ in
                                isHoldingMic = false
                                if speech.isListening { speech.stop() }
                            }
                    )

                    if !speech.transcript.isEmpty {
                        Text("“\(speech.transcript)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if draft != nil {
                        Button(L10n.string("voice.clear")) {
                            draft = nil
                            amountText = ""
                            note = ""
                            autoAssigned = false
                            speech.clearTranscript()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var formBlock: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.amount"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .glassField()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.currency"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker(L10n.string("field.currency"), selection: $entryCurrency) {
                        ForEach(AppCurrency.allCases) { code in
                            Text("\(code.displaySymbol) · \(code.code)").tag(code)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.type"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        typeChip(.expense, title: L10n.string("type.expense"))
                        typeChip(.income, title: L10n.string("type.income"))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.string("field.category"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if autoAssigned {
                            Text(L10n.string("category.auto"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: AppTheme.continuousRect(AppTheme.radiusControl))
                                .foregroundStyle(.secondary)
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
                                        size: 26
                                    )
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

                DatePicker(
                    L10n.string("field.date"),
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private func typeChip(_ value: TransactionType, title: String) -> some View {
        Button {
            type = value
            autoAssigned = false
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .padding(.vertical, 10)
                .glassChip(selected: type == value)
                .foregroundStyle(type == value ? Color.primary : Color.secondary)
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
            source: mode == .voice ? .voice : .manual,
            currency: entryCurrency,
            paymentMethod: paymentMethod
        )
        modelContext.insert(tx)
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()

        amountText = ""
        note = ""
        draft = nil
        autoAssigned = false
        speech.clearTranscript()
        if embeddedInSheet {
            dismiss()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
