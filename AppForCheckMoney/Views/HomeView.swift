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
        Array(transactions.prefix(8))
    }

    private func category(for tx: MoneyTransaction) -> MoneyCategory? {
        categories.first { $0.id == tx.categoryId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("home.balance"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(MoneyFormat.currency(balance))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(balance >= 0 ? .primary : Color(hex: "FF3B30"))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                metricChip(
                                    title: L10n.string("home.income"),
                                    value: MoneyFormat.currency(income),
                                    tint: Color(hex: "34C759")
                                )
                                metricChip(
                                    title: L10n.string("home.expense"),
                                    value: MoneyFormat.currency(expense),
                                    tint: Color(hex: "FF3B30")
                                )
                            }
                            .padding(.top, 8)
                        }
                    }

                    // Quick voice entry — one tap → listen → autosave on happy path
                    quickEntryControl

                    HStack {
                        Text(L10n.string("home.recent"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                    }

                    if recent.isEmpty {
                        GlassCard {
                            ContentUnavailableView(
                                L10n.string("home.empty"),
                                systemImage: "tray",
                                description: Text(L10n.string("home.emptyHint"))
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    } else {
                        GlassCard {
                            LazyVStack(spacing: 0) {
                                ForEach(recent, id: \.id) { tx in
                                    TransactionRowView(transaction: tx, category: category(for: tx))
                                    if tx.id != recent.last?.id {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.string("app.name"))
            .navigationBarTitleDisplayMode(.large)
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
                confirmSheet(for: box.draft)
            }
            .alert(
                statusMessage ?? "",
                isPresented: $showStatus
            ) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            }
        }
    }

    private var quickEntryControl: some View {
        GlassCard {
            VStack(spacing: 12) {
                Button {
                    toggleQuickListen()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                            .font(.title2.weight(.semibold))
                        VStack(alignment: .leading, spacing: 2) {
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
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(speech.isListening ? Color(hex: "FF3B30") : Color(hex: "0A84FF"))
                    )
                }
                .buttonStyle(.plain)
                .disabled({
                    if case .unavailable = speech.status { return true }
                    if case .failed = speech.status { return true }
                    return false
                }())

                if case .unavailable(let message) = speech.status {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if case .failed(let message) = speech.status {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "FF3B30"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if speech.isListening, !speech.transcript.isEmpty {
                    Text("“\(speech.transcript)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func toggleQuickListen() {
        if speech.isListening {
            speech.stop()
        } else {
            speech.start()
        }
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

    @ViewBuilder
    private func confirmSheet(for draft: VoiceDraft) -> some View {
        let cats = CategoryMatcher.categories(for: draft.type ?? .expense, in: categories)
        NavigationStack {
            Form {
                Section {
                    Text(MoneyFormat.currency(draft.amount ?? 0))
                        .font(.title.weight(.bold))
                    Text(draft.rawText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !draft.note.isEmpty {
                        LabeledContent(L10n.string("field.note"), value: draft.note)
                    }
                }
                Section(L10n.string("field.category")) {
                    Picker(L10n.string("field.category"), selection: Binding(
                        get: { overrideCategoryId ?? draft.categoryId ?? cats.first?.id ?? "" },
                        set: { overrideCategoryId = $0 }
                    )) {
                        ForEach(cats, id: \.id) { cat in
                            Text(cat.displayName()).tag(cat.id)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle(L10n.string("common.confirm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { pendingDraft = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        let id = overrideCategoryId ?? draft.categoryId
                        guard let id else { return }
                        save(draft, categoryId: id)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func metricChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Identifiable box so we can present a VoiceDraft in a sheet.
private struct PendingDraftBox: Identifiable {
    let draft: VoiceDraft
    var id: String { draft.rawText + String(draft.amount ?? -1) }
}
