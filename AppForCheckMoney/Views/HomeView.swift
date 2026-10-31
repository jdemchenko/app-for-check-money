import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.launchHomePulseToken) private var launchHomePulseToken
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \MoneyTransaction.createdAt, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \MoneyCategory.sortOrder)
    private var categories: [MoneyCategory]

    @ObservedObject private var currencySettings = CurrencySettings.shared
    @EnvironmentObject private var settings: AppSettingsStore
    @StateObject private var speech = SpeechRecognizer()
    @State private var pendingDraft: VoiceDraft?
    @State private var pendingBatch: [VoiceDraft]?
    @State private var pendingBatchPhrase: String = ""
    @State private var pendingRecurring: VoiceDraft?
    @State private var overrideCategoryId: String?
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var showManualAdd = false
    @State private var showSettings = false
    @State private var showLedger = false
    @State private var isHoldingMic = false
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    /// Soft day-total / category % after save (DeepSeek-style, no toast).
    @State private var quietFeedback: String?
    @State private var quietFeedbackTask: Task<Void, Never>?
    @ObservedObject private var incoming = IncomingDraftStore.shared
    /// One-shot hero reveal / mic pulse (LaunchWowStore — cold + return).
    @State private var balanceReveal: Double = 1
    @State private var displayedBalance: Double = 0
    @State private var balanceBlur: CGFloat = 0
    @State private var micLaunchPulse = false
    @State private var heroAppeared = false
    /// Soft under-budget cue — once per process, not confetti spam.
    @State private var budgetCelebrateShown = false
    @State private var budgetUnderGlow = false

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

    /// Month cashflow (income − expense) in display currency.
    private var monthCashflow: Double { income - expense }

    /// Multi-account FX total (opening + signed txs) in display currency.
    private var ledgerTotal: Double {
        AccountLedger.totals(
            accounts: accounts,
            transactions: transactions,
            displayCurrency: displayCurrency
        ).totalDisplay
    }

    private var balance: Double { ledgerTotal }

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
                    // First viewport: brand + balance + one CTA (hold-to-talk). No dashboard dump.
                    firstViewport
                    if let quietFeedback {
                        Text(quietFeedback)
                            .font(.footnote)
                            .themeSecondary()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .accessibilityLabel(quietFeedback)
                    }
                    secondaryGlance
                    recentBlock
                }
                .animation(AppTheme.springFluid, value: quietFeedback)
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .liquidScreen()
            // Brand lives in the first viewport hero — keep nav chrome quiet.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showLedger = true
                        } label: {
                            Image(systemName: "wallet.pass")
                        }
                        .accessibilityLabel(L10n.string("ledger.title"))

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
                .presentationCornerRadius(AppTheme.radiusPanel)
            }
            .sheet(isPresented: $showManualAdd) {
                NavigationStack {
                    AddTransactionView(embeddedInSheet: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppTheme.radiusPanel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppTheme.radiusPanel)
            }
            .sheet(isPresented: $showLedger) {
                LedgerHubView()
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppTheme.radiusPanel)
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
            .animation(AppTheme.springFluid, value: pendingBatch?.count)
            .animation(AppTheme.springFluid, value: pendingRecurring?.rawText)
            .onChange(of: incoming.pendingText) { _, _ in
                consumeIncomingDraft()
            }
            .onAppear {
                consumeIncomingDraft()
                if !heroAppeared, launchHomePulseToken == 0 {
                    displayedBalance = balance
                    balanceBlur = 0
                    balanceReveal = 1
                }
            }
            .onChange(of: launchHomePulseToken) { _, token in
                guard token > 0 else { return }
                runHeroReveal()
            }
            .onChange(of: balance) { _, newValue in
                guard heroAppeared, !reduceMotion else {
                    displayedBalance = newValue
                    return
                }
                withAnimation(AppTheme.springFluid) {
                    displayedBalance = newValue
                }
            }
            .id(currencySettings.displayCurrency.rawValue)
        }
    }

    /// Count-up + blur→sharp + one mic glass pulse (cold handoff or return open).
    private func runHeroReveal() {
        heroAppeared = true
        if reduceMotion {
            displayedBalance = balance
            balanceBlur = 0
            balanceReveal = 1
            micLaunchPulse = false
            return
        }
        displayedBalance = 0
        balanceBlur = 12
        balanceReveal = 0.4
        micLaunchPulse = false
        withAnimation(AppTheme.springFluid) {
            displayedBalance = balance
            balanceBlur = 0
            balanceReveal = 1
        }
        withAnimation(AppTheme.springPress) {
            micLaunchPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(AppTheme.springFluid) {
                micLaunchPulse = false
            }
        }
    }

    @ViewBuilder
    private func batchConfirmOverlay(_ batch: [VoiceDraft]) -> some View {
        VoiceBatchConfirmView(
            phrase: pendingBatchPhrase.isEmpty
                ? batch.map(\.rawText).joined(separator: " · ")
                : pendingBatchPhrase,
            drafts: batch,
            categories: categories,
            accounts: accounts,
            displayCurrency: displayCurrency,
            entryCurrency: currencySettings.entryCurrency,
            onConfirm: { saveBatch(batch) },
            onCancel: {
                pendingBatch = nil
                pendingBatchPhrase = ""
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }

    // MARK: - Sections

    /// Brand-forward balance + hold-to-talk. No card chrome in the hero.
    private var firstViewport: some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceGroup) {
            Text(L10n.string("app.name"))
                .font(AppTheme.TypeScale.largeTitle)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            AnimatedCurrencyLabel(amount: displayedBalance, code: displayCurrency)
                .font(AppTheme.TypeScale.moneyHero)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .blur(radius: balanceBlur)
                .opacity(balanceReveal)
                .offset(y: (1 - balanceReveal) * 10)

            Text(
                L10n.string("home.monthCashflow")
                    + " · "
                    + MoneyFormat.currency(monthCashflow, code: displayCurrency)
            )
            .font(AppTheme.TypeScale.subheadline)
            .themeTertiary()

            quickMic
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.spaceTight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Below-fold glance: income/expense, today, budgets — one quiet panel, not hero clutter.
    private var secondaryGlance: some View {
        GlassPanel(padding: 18) {
            VStack(alignment: .leading, spacing: AppTheme.spaceItem) {
                HStack(spacing: 20) {
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

                    Spacer(minLength: 0)
                }
                .font(.footnote)

                if todayExpense > 0 {
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
                                AppTheme.continuousRect(3)
                                    .fill(AppTheme.trackFill(colorScheme))
                                AppTheme.continuousRect(3)
                                    .fill(AppTheme.trackValue(colorScheme, emphasized: progress >= 1))
                                    .frame(width: max(4, geo.size.width * progress))
                            }
                        }
                        .frame(height: 4)
                        .clipShape(AppTheme.continuousRect(3))
                        .accessibilityLabel(L10n.string("budget.title"))
                        .accessibilityValue("\(Int((progress * 100).rounded()))%")
                    }
                }

                if !activeCategoryBudgetRows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("budget.categories"))
                            .font(.caption.weight(.medium))
                            .themeSecondary()
                        ForEach(activeCategoryBudgetRows.prefix(3), id: \.id) { row in
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
                                    AppTheme.continuousRect(2)
                                        .fill(AppTheme.trackFill(colorScheme))
                                    AppTheme.continuousRect(2)
                                        .fill(AppTheme.trackValue(colorScheme, emphasized: row.progress >= 1))
                                        .frame(width: max(4, geo.size.width * row.progress))
                                }
                            }
                            .frame(height: 3)
                            .clipShape(AppTheme.continuousRect(2))
                        }
                    }
                }
            }
        }
        .overlay {
            AppTheme.continuousRect(AppTheme.radiusPanel)
                .strokeBorder(
                    AppTheme.income.opacity(budgetUnderGlow ? 0.45 : 0),
                    lineWidth: AppTheme.borderWidth
                )
                .animation(AppTheme.springFluid, value: budgetUnderGlow)
                .allowsHitTesting(false)
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

    /// Hold to talk — the single primary CTA in the first viewport.
    private var quickMic: some View {
        VStack(spacing: 12) {
            Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(speech.isListening ? AppTheme.accent : Color.primary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: speech.isListening)
                .quietInteractiveGlassCircle(listening: speech.isListening || micLaunchPulse)
                .scaleEffect(
                    isHoldingMic || speech.isListening || micLaunchPulse ? 1.05 : 1.0
                )
                .animation(AppTheme.springSnappy, value: isHoldingMic)
                .animation(AppTheme.springSnappy, value: speech.isListening)
                .animation(AppTheme.springSnappy, value: micLaunchPulse)
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
            .font(AppTheme.TypeScale.subheadline.weight(.semibold))

            Text(
                speech.isListening
                    ? L10n.string("home.quickEntryStop")
                    : L10n.string("home.quickEntryHint")
            )
            .font(AppTheme.TypeScale.footnote)
            .themeTertiary()
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)

            if case .unavailable(let message) = speech.status {
                Text(message)
                    .font(.caption)
                    .themeTertiary()
                    .multilineTextAlignment(.center)
            } else if case .failed(let message) = speech.status {
                Text(message)
                    .font(.caption)
                    .themeTertiary()
            } else if speech.isListening, !speech.transcript.isEmpty {
                Text("“\(speech.transcript)”")
                    .font(.footnote)
                    .themeSecondary()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        AppTheme.continuousRect(AppTheme.radiusControl)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .strokeBorder(AppTheme.hairline(colorScheme), lineWidth: AppTheme.borderWidth)
                            }
                    }
            }

            Button {
                pasteClipboardDraft()
            } label: {
                Text(L10n.string("home.pasteDraft"))
                    .font(.caption.weight(.medium))
                    .themeTertiary()
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
                    .font(AppTheme.TypeScale.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .quietPress(scale: 0.98)
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
            pendingBatchPhrase = trimmed
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
            date: draft.resolvedDate(),
            source: .voice,
            currency: draft.currency ?? currencySettings.entryCurrency
        )
        modelContext.insert(tx)
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        speech.clearTranscript()
        pendingDraft = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // No «Готово» toast — optional quiet day / category % (DeepSeek metrics, ADA-quiet).
        if (draft.type ?? .expense) == .expense {
            presentQuietFeedback(for: tx)
        } else {
            quietFeedback = nil
            maybeCelebrateBudgetUnderLimit()
        }
    }

    private func saveBatch(_ batch: [VoiceDraft]) {
        var lastExpense: MoneyTransaction?
        for draft in batch {
            guard let amount = draft.amount, amount > 0 else { continue }
            let categoryId = draft.categoryId
                ?? CategoryMatcher.categories(for: draft.type ?? .expense, in: categories).first?.id
            guard let categoryId else { continue }
            let currency = draft.currency ?? currencySettings.entryCurrency
            let tx = MoneyTransaction(
                amount: amount,
                type: draft.type ?? .expense,
                categoryId: categoryId,
                note: draft.note.isEmpty ? nil : draft.note,
                date: draft.resolvedDate(),
                source: .voice,
                currency: currency
            )
            modelContext.insert(tx)
            if tx.type == .expense { lastExpense = tx }
            // Subscription clause → also draft a RecurringRule (on-device).
            if let frequency = draft.frequency {
                let rule = RecurringRule(
                    amount: amount,
                    type: draft.type ?? .expense,
                    categoryId: categoryId,
                    note: draft.note.isEmpty ? nil : draft.note,
                    currency: currency,
                    frequency: frequency,
                    nextFireDate: Calendar.current.date(
                        byAdding: frequency == .weekly ? .day : .month,
                        value: 1,
                        to: draft.resolvedDate()
                    ) ?? draft.resolvedDate()
                )
                modelContext.insert(rule)
            }
        }
        try? modelContext.save()
        PhoneWatchSync.shared.pushSnapshot()
        pendingBatch = nil
        pendingBatchPhrase = ""
        speech.clearTranscript()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let lastExpense {
            presentQuietFeedback(for: lastExpense)
        } else {
            maybeCelebrateBudgetUnderLimit()
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
        maybeCelebrateBudgetUnderLimit()
        quietFeedbackTask?.cancel()
        quietFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(AppTheme.springFluid) {
                quietFeedback = nil
                budgetUnderGlow = false
            }
        }
    }

    /// Subtle under-budget celebration — once per process, no confetti.
    private func maybeCelebrateBudgetUnderLimit() {
        guard settings.budgetEnabled, settings.budgetAmount > 0 else { return }
        guard !budgetCelebrateShown else { return }
        let spent = monthBudgetSpent
        guard spent > 0, spent < settings.budgetAmount else { return }
        budgetCelebrateShown = true
        budgetUnderGlow = true
        let remaining = settings.budgetAmount - spent
        let line = String(
            format: L10n.string("home.budgetUnder"),
            MoneyFormat.currency(remaining, code: settings.budgetCurrency)
        )
        if let existing = quietFeedback, !existing.isEmpty {
            quietFeedback = existing + " · " + line
        } else {
            quietFeedback = line
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(AppTheme.springFluid) {
                budgetUnderGlow = false
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var cats: [MoneyCategory] {
        CategoryMatcher.categories(for: draft.type ?? .expense, in: categories)
    }

    private var canSave: Bool { !categoryId.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spaceGroup) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                MoneyFormat.currency(
                                    draft.amount ?? 0,
                                    code: draft.currency ?? CurrencySettings.shared.entryCurrency
                                )
                            )
                            .font(AppTheme.TypeScale.moneyTitle)
                            Text(draft.rawText)
                                .font(AppTheme.TypeScale.footnote)
                                .foregroundStyle(.secondary)
                            if !draft.note.isEmpty {
                                Text(draft.note)
                                    .font(AppTheme.TypeScale.subheadline.weight(.medium))
                            }
                        }
                    }
                    .opacity(revealed || reduceMotion ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 10)

                    QuietSectionLabel(text: L10n.string("field.category"))
                        .opacity(revealed || reduceMotion ? 1 : 0)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(Array(cats.enumerated()), id: \.element.id) { index, cat in
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
                                        .font(AppTheme.TypeScale.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .glassChip(selected: categoryId == cat.id)
                            }
                            .quietPress()
                            .opacity(chipVisible(index) ? 1 : 0)
                            .offset(y: chipVisible(index) ? 0 : 12)
                            .animation(
                                AppTheme.springFluid.delay(reduceMotion ? 0 : 0.05 + Double(index) * 0.045),
                                value: revealed
                            )
                        }
                    }
                }
                .padding(20)
                .animation(AppTheme.springFluid, value: revealed)
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
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave(categoryId)
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if reduceMotion {
                    revealed = true
                } else {
                    revealed = false
                    DispatchQueue.main.async {
                        withAnimation(AppTheme.springFluid) { revealed = true }
                    }
                }
            }
        }
    }

    private func chipVisible(_ index: Int) -> Bool {
        reduceMotion || revealed
    }
}

private struct PendingDraftBox: Identifiable {
    let draft: VoiceDraft
    var id: String { draft.rawText + String(draft.amount ?? -1) }
}
