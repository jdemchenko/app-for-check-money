import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \MoneyTransaction.createdAt, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @ObservedObject private var currencySettings = CurrencySettings.shared
    @EnvironmentObject private var settings: AppSettingsStore
    @StateObject private var speech = SpeechRecognizer()
    @State private var pendingDraft: VoiceDraft?
    @State private var pendingBatch: [VoiceDraft]?
    @State private var pendingRecurring: VoiceDraft?
    @State private var overrideCategoryId: String?
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var showManualAdd = false
    @State private var showSettings = false
    @State private var isHoldingMic = false
    /// Soft day-total / category % after save (DeepSeek-style, no toast).
    @State private var quietFeedback: String?
    @State private var quietFeedbackTask: Task<Void, Never>?
    @ObservedObject private var incoming = IncomingDraftStore.shared

    private var monthTransactions: [MoneyTransaction] {
        let cal = Calendar.current
        let now = Date.now
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return transactions }
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return transactions.filter { $0.date >= start && $0.date <= endOfDay }
    }

    private var displayCurrency: AppCurrency { currencySettings.displayCurrency }

    private var income: Double {
        monthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amountIn(displayCurrency) }
    }

    private var expense: Double {
        monthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amountIn(displayCurrency) }
    }

    private var balance: Double { income - expense }

    private var todayExpense: Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        return transactions
            .filter { $0.type == .expense && $0.date >= start }
            .reduce(0) { $0 + $1.amountIn(displayCurrency) }
    }

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
                    if let quietFeedback {
                        Text(quietFeedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .accessibilityLabel(quietFeedback)
                    }
                    quickMic
                    recentBlock
                }
                .animation(.easeOut(duration: 0.28), value: quietFeedback)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("app.name"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(L10n.string("settings.title"))

                        Button {
                            showManualAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                        .accessibilityLabel(L10n.string("tab.add"))
                    }
                }
            }
            .onAppear {
                speech.allowsSilenceFinish = false
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showManualAdd) {
                NavigationStack {
                    AddTransactionView(embeddedInSheet: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
            }
            .alert(statusMessage ?? "", isPresented: $showStatus) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            }
            .overlay {
                if let batch = pendingBatch {
                    batchConfirmOverlay(batch)
                } else if let recurring = pendingRecurring {
                    recurringConfirmOverlay(recurring)
                }
            }
            .animation(.easeOut(duration: 0.2), value: pendingBatch?.count)
            .animation(.easeOut(duration: 0.2), value: pendingRecurring?.rawText)
            .onChange(of: incoming.pendingText) { _, _ in
                consumeIncomingDraft()
            }
            .onAppear { consumeIncomingDraft() }
            .id(currencySettings.displayCurrency.rawValue)
        }
    }

    @ViewBuilder
    private func batchConfirmOverlay(_ batch: [VoiceDraft]) -> some View {
        let lines = batch.map { draft in
            let amount = MoneyFormat.currency(
                draft.amount ?? 0,
                code: draft.currency ?? currencySettings.entryCurrency
            )
            let cat = categories.first { $0.id == draft.categoryId }?.displayName() ?? "—"
            let note = draft.note.isEmpty ? cat : draft.note
            return "\(amount) · \(note)"
        }.joined(separator: "\n")

        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { pendingBatch = nil }
            QuietConfirmPanel(
                title: L10n.string("voice.batchTitle"),
                message: lines,
                confirmTitle: L10n.string("voice.batchSave"),
                confirmDestructive: false,
                onConfirm: { saveBatch(batch) },
                onCancel: { pendingBatch = nil }
            )
        }
        .transition(.opacity)
        .zIndex(10)
    }

    @ViewBuilder
    private func recurringConfirmOverlay(_ draft: VoiceDraft) -> some View {
        let amount = MoneyFormat.currency(
            draft.amount ?? 0,
            code: draft.currency ?? currencySettings.entryCurrency
        )
        let freq = draft.frequency?.title ?? L10n.string("recurring.monthly")
        let cat = categories.first { $0.id == draft.categoryId }?.displayName() ?? "—"
        let detail = [amount, freq, cat, draft.note].filter { !$0.isEmpty }.joined(separator: " · ")

        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { pendingRecurring = nil }
            QuietConfirmPanel(
                title: L10n.string("voice.recurringTitle"),
                message: detail,
                confirmTitle: L10n.string("voice.recurringSave"),
                confirmDestructive: false,
                onConfirm: { saveRecurring(draft) },
                onCancel: { pendingRecurring = nil }
            )
        }
        .transition(.opacity)
        .zIndex(10)
    }

    // MARK: - Sections

    private var balanceHero: some View {
        GlassPanel(padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("home.balance"))
                    .font(.footnote.weight(.medium))
                    .themeSecondary()

                Text(MoneyFormat.currency(balance, code: displayCurrency))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text(L10n.string("home.monthIn") + " " + displayCurrency.displaySymbol)
                    .font(.caption2)
                    .themeTertiary()

                HStack(spacing: 16) {
                    Label {
                        Text(MoneyFormat.currency(income, code: displayCurrency))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                    } icon: {
                        Image(systemName: "arrow.down.left")
                    }
                    .foregroundStyle(AppTheme.income)

                    Label {
                        Text(MoneyFormat.currency(expense, code: displayCurrency))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                    } icon: {
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(AppTheme.expense)
                }
                .font(.footnote)
                .padding(.top, 2)

                // Quiet “today” strip — Spendee/Money Lover glance without extra cards.
                if todayExpense > 0 {
                    Divider().opacity(colorScheme == .dark ? 0.22 : 0.14).padding(.vertical, 2)
                    HStack {
                        Text(L10n.string("home.today"))
                            .font(.caption.weight(.medium))
                            .themeSecondary()
                        Spacer(minLength: 8)
                        Text("−" + MoneyFormat.currency(todayExpense, code: displayCurrency))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.expense)
                    }
                    .accessibilityElement(children: .combine)
                }

                if settings.budgetEnabled, settings.budgetAmount > 0 {
                    let spent = monthBudgetSpent
                    let limit = settings.budgetAmount
                    let progress = min(1, max(0, spent / limit))
                    Divider().opacity(colorScheme == .dark ? 0.22 : 0.14).padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.string("budget.title"))
                                .font(.caption.weight(.medium))
                                .themeSecondary()
                            Spacer(minLength: 8)
                            Text(
                                MoneyFormat.currency(spent, code: settings.budgetCurrency)
                                    + " / "
                                    + MoneyFormat.currency(limit, code: settings.budgetCurrency)
                            )
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(
                                progress >= 1 ? AppTheme.expense : AppTheme.labelSecondary(colorScheme)
                            )
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .fill(AppTheme.trackFill(colorScheme))
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .fill(AppTheme.trackValue(colorScheme, emphasized: progress >= 1))
                                    .frame(width: max(4, geo.size.width * progress))
                            }
                        }
                        .frame(height: 5)
                        .clipShape(AppTheme.continuousRect(AppTheme.radiusControl))
                        .accessibilityLabel(L10n.string("budget.title"))
                        .accessibilityValue("\(Int((progress * 100).rounded()))%")
                    }
                }

                if !activeCategoryBudgetRows.isEmpty {
                    Divider().opacity(colorScheme == .dark ? 0.22 : 0.14).padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("budget.categories"))
                            .font(.caption.weight(.medium))
                            .themeSecondary()
                        ForEach(activeCategoryBudgetRows, id: \.id) { row in
                            HStack {
                                Text(row.name)
                                    .font(.caption)
                                    .themeSecondary()
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(
                                    MoneyFormat.currency(row.spent, code: settings.budgetCurrency)
                                        + " / "
                                        + MoneyFormat.currency(row.limit, code: settings.budgetCurrency)
                                )
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(
                                    row.progress >= 1 ? AppTheme.expense : AppTheme.labelSecondary(colorScheme)
                                )
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(AppTheme.trackFill(colorScheme))
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .fill(AppTheme.trackValue(colorScheme, emphasized: row.progress >= 1))
                                        .frame(width: max(4, geo.size.width * row.progress))
                                }
                            }
                            .frame(height: 3)
                            .clipShape(AppTheme.continuousRect(AppTheme.radiusControl))
                        }
                    }
                }
            }
        }
    }

    private struct CategoryBudgetRow {
        let id: String
        let name: String
        let spent: Double
        let limit: Double
        var progress: Double { min(1, max(0, spent / max(limit, 0.0001))) }
    }

    private var activeCategoryBudgetRows: [CategoryBudgetRow] {
        settings.categoryBudgets.keys.compactMap { id -> CategoryBudgetRow? in
            guard let limit = settings.categoryBudget(for: id) else { return nil }
            let cat = categories.first { $0.id == id }
            let spent = monthTransactions
                .filter { $0.type == .expense && $0.categoryId == id }
                .reduce(0.0) { $0 + $1.amountIn(settings.budgetCurrency) }
            return CategoryBudgetRow(
                id: id,
                name: cat?.displayName() ?? L10n.string("category.unknown"),
                spent: spent,
                limit: limit
            )
        }
        .sorted { $0.progress > $1.progress }
    }

    private var monthBudgetSpent: Double {
        monthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amountIn(settings.budgetCurrency) }
    }

    /// Hold to talk — press starts listening, release stops and saves.
    private var quickMic: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 108, height: 108)
                    .overlay {
                        Circle()
                            .fill(Color.primary.opacity(speech.isListening ? 0.12 : 0.06))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(AppTheme.glassStroke(colorScheme), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 8)

                Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: speech.isListening)
            }
            .scaleEffect(isHoldingMic || speech.isListening ? 1.06 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHoldingMic)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: speech.isListening)
            // Use weight-based impact (iOS 17+). Avoid `.impact(flexibility:)` /
            // `SensoryFeedback.Flexibility` — those require a newer SDK than iOS 18.
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: isHoldingMic)
            .frame(minWidth: AppTheme.touchMin, minHeight: AppTheme.touchMin)
            .contentShape(Circle())
            .gesture(holdToTalkGesture)
            .disabled({
                if case .unavailable = speech.status { return true }
                if case .failed = speech.status { return true }
                return false
            }())
            .accessibilityLabel(L10n.string("home.quickEntry"))
            .accessibilityHint(L10n.string("home.quickEntryHint"))

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
                    .foregroundStyle(.secondary)
            } else if speech.isListening, !speech.transcript.isEmpty {
                Text("“\(speech.transcript)”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        AppTheme.continuousRect(AppTheme.radiusControl)
                            .fill(.thinMaterial)
                    }
            }

            Button {
                pasteClipboardDraft()
            } label: {
                Text(L10n.string("home.pasteDraft"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.string("home.pasteDraftHint"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var holdToTalkGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isHoldingMic else { return }
                isHoldingMic = true
                if !speech.isListening {
                    speech.start()
                }
            }
            .onEnded { _ in
                isHoldingMic = false
                if speech.isListening {
                    speech.stop()
                }
            }
    }

    private var recentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                QuietSectionLabel(text: L10n.string("home.recent"))
                Spacer(minLength: 8)
                if !recent.isEmpty {
                    Button(L10n.string("home.seeAll")) {
                        selectedTab = .history
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            if recent.isEmpty {
                GlassPanel(padding: 28, corner: AppTheme.cornerMedium) {
                    ContentUnavailableView(
                        L10n.string("home.empty"),
                        systemImage: "mic.fill",
                        description: Text(L10n.string("home.emptyHint"))
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                    LazyVStack(spacing: 0) {
                        ForEach(recent, id: \.id) { tx in
                            TransactionRowView(
                                transaction: tx,
                                category: category(for: tx),
                                displayCurrency: displayCurrency
                            )
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

    private func handleUtterance(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            flash(L10n.string("home.quickEntryEmpty"))
            return
        }
        let drafts = VoiceParser.parseMany(rawText: trimmed, categories: categories)
        guard let first = drafts.first else {
            flash(L10n.string("home.quickEntryNoAmount"))
            return
        }

        if drafts.count >= 2 {
            pendingBatch = drafts
            speech.clearTranscript()
            return
        }

        if first.isRecurring, first.amount != nil {
            pendingRecurring = first
            speech.clearTranscript()
            return
        }

        if first.isAutosaveReady {
            save(first, categoryId: first.categoryId!)
            return
        }
        if first.amount != nil {
            overrideCategoryId = first.categoryId
            pendingDraft = first
        } else {
            flash(L10n.string("home.quickEntryNoAmount"))
        }
    }

    private func consumeIncomingDraft() {
        guard let text = incoming.consume() else { return }
        handleUtterance(text)
    }

    private func pasteClipboardDraft() {
        guard let text = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            flash(L10n.string("home.pasteEmpty"))
            return
        }
        handleUtterance(text)
    }

    private func save(_ draft: VoiceDraft, categoryId: String) {
        guard let amount = draft.amount, amount > 0 else { return }
        let tx = MoneyTransaction(
            amount: amount,
            type: draft.type ?? .expense,
            categoryId: categoryId,
            note: draft.note.isEmpty ? nil : draft.note,
            date: .now,
            source: .voice,
            currency: draft.currency ?? currencySettings.entryCurrency
        )
        modelContext.insert(tx)
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        speech.clearTranscript()
        pendingDraft = nil
        // No «Готово» toast — optional quiet day / category % (DeepSeek metrics, ADA-quiet).
        if (draft.type ?? .expense) == .expense {
            presentQuietFeedback(for: tx)
        } else {
            quietFeedback = nil
        }
    }

    private func saveBatch(_ batch: [VoiceDraft]) {
        var lastExpense: MoneyTransaction?
        for draft in batch {
            guard let amount = draft.amount, amount > 0 else { continue }
            let categoryId = draft.categoryId
                ?? CategoryMatcher.categories(for: draft.type ?? .expense, in: categories).first?.id
            guard let categoryId else { continue }
            let tx = MoneyTransaction(
                amount: amount,
                type: draft.type ?? .expense,
                categoryId: categoryId,
                note: draft.note.isEmpty ? nil : draft.note,
                date: .now,
                source: .voice,
                currency: draft.currency ?? currencySettings.entryCurrency
            )
            modelContext.insert(tx)
            if tx.type == .expense { lastExpense = tx }
        }
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        pendingBatch = nil
        speech.clearTranscript()
        if let lastExpense {
            presentQuietFeedback(for: lastExpense)
        }
    }

    private func saveRecurring(_ draft: VoiceDraft) {
        guard let amount = draft.amount, amount > 0,
              let frequency = draft.frequency
        else {
            pendingRecurring = nil
            return
        }
        let categoryId = draft.categoryId
            ?? CategoryMatcher.categories(for: draft.type ?? .expense, in: categories).first?.id
        guard let categoryId else {
            pendingRecurring = nil
            flash(L10n.string("home.quickEntryNoAmount"))
            return
        }
        let rule = RecurringRule(
            amount: amount,
            type: draft.type ?? .expense,
            categoryId: categoryId,
            note: draft.note.isEmpty ? nil : draft.note,
            currency: draft.currency ?? currencySettings.entryCurrency,
            frequency: frequency,
            nextFireDate: .now
        )
        modelContext.insert(rule)
        _ = RecurringEngine.applyDue(in: modelContext)
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        pendingRecurring = nil
        quietFeedback = L10n.string("voice.recurringSaved")
        quietFeedbackTask?.cancel()
        quietFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { quietFeedback = nil }
        }
    }

    private func presentQuietFeedback(for tx: MoneyTransaction) {
        let all = (try? modelContext.fetch(FetchDescriptor<MoneyTransaction>())) ?? transactions
        let tip = StatsEngine.quietFeedback(
            after: tx,
            all: all,
            categories: categories,
            displayCurrency: displayCurrency
        )
        let total = MoneyFormat.currency(tip.dayTotal, code: displayCurrency)
        let pct = tip.categoryPercent.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(tip.categoryPercent))
            : String(format: "%.1f", tip.categoryPercent)
        quietFeedback = String(
            format: L10n.string("home.quietFeedback"),
            total,
            tip.categoryName,
            pct
        )
        quietFeedbackTask?.cancel()
        quietFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                quietFeedback = nil
            }
        }
    }

    private func flash(_ message: String) {
        statusMessage = message
        showStatus = true
    }
}

// MARK: - Confirm sheet

struct ConfirmDraftSheet: View {
    let draft: VoiceDraft
    let categories: [MoneyCategory]
    @Binding var categoryId: String
    var onCancel: () -> Void
    var onSave: (String) -> Void

    private var cats: [MoneyCategory] {
        CategoryMatcher.categories(for: draft.type ?? .expense, in: categories)
    }

    private var canSave: Bool { !categoryId.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                MoneyFormat.currency(
                                    draft.amount ?? 0,
                                    code: draft.currency ?? CurrencySettings.shared.entryCurrency
                                )
                            )
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
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
                                .glassChip(selected: categoryId == cat.id)
                            }
                            .buttonStyle(.plain)
                        }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        guard canSave else { return }
                        onSave(categoryId)
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct PendingDraftBox: Identifiable {
    let draft: VoiceDraft
    var id: String { draft.rawText + String(draft.amount ?? -1) }
}
