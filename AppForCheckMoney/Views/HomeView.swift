import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyTransaction.createdAt, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @StateObject private var speech = SpeechRecognizer()
    @State private var pendingDraft: VoiceDraft?
    @State private var overrideCategoryId: String?
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var showManualAdd = false
    @State private var showIconSettings = false

    private var monthTransactions: [MoneyTransaction] {
        let cal = Calendar.current
        let now = Date.now
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return transactions }
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return transactions.filter { $0.date >= start && $0.date <= endOfDay }
    }

    private var income: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double { income - expense }

    private var recent: [MoneyTransaction] {
        Array(transactions.prefix(6))
    }

    private func category(for tx: MoneyTransaction) -> MoneyCategory? {
        categories.first { $0.id == tx.categoryId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spaceSection) {
                    balanceHero
                    quickMic
                    recentBlock
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("app.name"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showManualAdd = true
                        } label: {
                            Label(L10n.string("tab.add"), systemImage: "plus")
                        }
                        Button {
                            showIconSettings = true
                        } label: {
                            Label(L10n.string("settings.icon.title"), systemImage: "app.badge")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(L10n.string("common.menu"))
                }
            }
            .onAppear {
                speech.onUtteranceFinished = { text in
                    handleUtterance(text)
                }
                Task { await speech.prepare() }
                #if DEBUG
                let fails = VoiceParser.debugSelfCheck(categories: categories)
                if !fails.isEmpty {
                    assertionFailure("VoiceParser self-check failed: \(fails)")
                }
                #endif
            }
            .sheet(item: Binding(
                get: { pendingDraft.map { PendingDraftBox(draft: $0) } },
                set: { pendingDraft = $0?.draft }
            )) { box in
                ConfirmDraftSheet(
                    draft: box.draft,
                    categories: categories,
                    categoryId: Binding(
                        get: { overrideCategoryId ?? box.draft.categoryId ?? "" },
                        set: { overrideCategoryId = $0 }
                    ),
                    onCancel: { pendingDraft = nil },
                    onSave: { id in save(box.draft, categoryId: id) }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showManualAdd) {
                NavigationStack {
                    AddTransactionView(embeddedInSheet: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showIconSettings) {
                AppIconSettingsView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert(statusMessage ?? "", isPresented: $showStatus) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private var balanceHero: some View {
        GlassPanel(padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("home.balance"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(MoneyFormat.currency(balance))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(balance >= 0 ? .primary : AppTheme.expense)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Label {
                        Text(MoneyFormat.currency(income))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    } icon: {
                        Image(systemName: "arrow.down.left")
                    }
                    .foregroundStyle(AppTheme.income)

                    Label {
                        Text(MoneyFormat.currency(expense))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    } icon: {
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(AppTheme.expense)
                }
                .font(.footnote)
                .padding(.top, 2)
            }
        }
    }

    /// Single primary action — floating glass mic orb.
    private var quickMic: some View {
        VStack(spacing: 14) {
            Button {
                toggleQuickListen()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 108, height: 108)
                        .overlay {
                            Circle()
                                .fill(
                                    (speech.isListening ? AppTheme.expense : AppTheme.accent)
                                        .opacity(0.88)
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AppTheme.glassStroke, lineWidth: 1.2)
                        }
                        .shadow(
                            color: (speech.isListening ? AppTheme.expense : AppTheme.accent)
                                .opacity(0.4),
                            radius: 22,
                            y: 10
                        )

                    Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .disabled({
                if case .unavailable = speech.status { return true }
                if case .failed = speech.status { return true }
                return false
            }())
            .accessibilityLabel(
                speech.isListening
                    ? L10n.string("voice.stop")
                    : L10n.string("home.quickEntry")
            )

            Text(
                speech.isListening
                    ? L10n.string("voice.listening")
                    : L10n.string("home.quickEntry")
            )
            .font(.headline)

            Text(
                speech.isListening
                    ? L10n.string("home.quickEntryStop")
                    : L10n.string("home.quickEntryHint")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)

            if case .unavailable(let message) = speech.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if case .failed(let message) = speech.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.expense)
            } else if speech.isListening, !speech.transcript.isEmpty {
                Text("“\(speech.transcript)”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.thinMaterial)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var recentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietSectionLabel(text: L10n.string("home.recent"))

            if recent.isEmpty {
                GlassPanel(padding: 28, corner: AppTheme.cornerMedium) {
                    ContentUnavailableView(
                        L10n.string("home.empty"),
                        systemImage: "tray",
                        description: Text(L10n.string("home.emptyHint"))
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                    LazyVStack(spacing: 0) {
                        ForEach(recent, id: \.id) { tx in
                            TransactionRowView(transaction: tx, category: category(for: tx))
                                .padding(.horizontal, 10)
                            if tx.id != recent.last?.id {
                                Divider().opacity(0.25).padding(.leading, 54)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleQuickListen() {
        if speech.isListening { speech.stop() } else { speech.start() }
    }

    private func handleUtterance(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            flash(L10n.string("home.quickEntryEmpty"))
            return
        }
        let draft = VoiceParser.parse(rawText: trimmed, categories: categories)
        if draft.isAutosaveReady {
            save(draft, categoryId: draft.categoryId!)
            return
        }
        if draft.amount != nil {
            overrideCategoryId = draft.categoryId
            pendingDraft = draft
        } else {
            flash(L10n.string("home.quickEntryNoAmount"))
        }
    }

    private func save(_ draft: VoiceDraft, categoryId: String) {
        guard let amount = draft.amount, amount > 0 else { return }
        let tx = MoneyTransaction(
            amount: amount,
            type: draft.type ?? .expense,
            categoryId: categoryId,
            note: draft.note.isEmpty ? nil : draft.note,
            date: .now,
            source: .voice
        )
        modelContext.insert(tx)
        try? modelContext.save()
        speech.clearTranscript()
        pendingDraft = nil
        flash(L10n.string("add.saved"))
    }

    private func flash(_ message: String) {
        statusMessage = message
        showStatus = true
    }
}

// MARK: - Confirm sheet (glass, minimal)

struct ConfirmDraftSheet: View {
    let draft: VoiceDraft
    let categories: [MoneyCategory]
    @Binding var categoryId: String
    var onCancel: () -> Void
    var onSave: (String) -> Void

    private var cats: [MoneyCategory] {
        CategoryMatcher.categories(for: draft.type ?? .expense, in: categories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(MoneyFormat.currency(draft.amount ?? 0))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text(draft.rawText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if !draft.note.isEmpty {
                                Text(draft.note)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }

                    QuietSectionLabel(text: L10n.string("field.category"))

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(cats, id: \.id) { cat in
                            Button {
                                categoryId = cat.id
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
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.thinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    categoryId == cat.id
                                                        ? AppTheme.accent.opacity(0.55)
                                                        : Color.white.opacity(0.2),
                                                    lineWidth: categoryId == cat.id ? 1.2 : 0.5
                                                )
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    GlassActionButton(title: L10n.string("common.save")) {
                        guard !categoryId.isEmpty else { return }
                        onSave(categoryId)
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("common.confirm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel"), action: onCancel)
                }
            }
        }
    }
}

private struct PendingDraftBox: Identifiable {
    let draft: VoiceDraft
    var id: String { draft.rawText + String(draft.amount ?? -1) }
}
