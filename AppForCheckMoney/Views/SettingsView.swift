import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @ObservedObject private var rates = ExchangeRateStore.shared
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]

    @State private var showRecurring = false
    @State private var showLedger = false
    @State private var budgetText: String = ""
    @State private var categoryBudgetTexts: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    currencyBlock(
                        title: L10n.string("settings.displayCurrency"),
                        subtitle: L10n.string("settings.displayCurrencyHint"),
                        selection: $currencySettings.displayCurrency
                    )

                    currencyBlock(
                        title: L10n.string("settings.entryCurrency"),
                        subtitle: L10n.string("settings.entryCurrencyHint"),
                        selection: $currencySettings.entryCurrency
                    )

                    ledgerLinkBlock
                    budgetBlock
                    categoryBudgetBlock
                    reminderBlock
                    securityBlock
                    privacyBlock
                    shortcutsBlock
                    recurringBlock
                    iCloudBlock
                    ratesBlock
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, 16)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .task {
                rates.refreshIfNeeded()
            }
            .onAppear {
                budgetText = settings.budgetAmount > 0
                    ? String(format: "%g", settings.budgetAmount)
                    : ""
                var texts: [String: String] = [:]
                for cat in categories where cat.kind.matches(.expense) {
                    if let limit = settings.categoryBudget(for: cat.id) {
                        texts[cat.id] = String(format: "%g", limit)
                    } else {
                        texts[cat.id] = ""
                    }
                }
                categoryBudgetTexts = texts
            }
            .sheet(isPresented: $showRecurring) {
                RecurringListView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLedger) {
                LedgerHubView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var ledgerLinkBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("ledger.title"))
            Button {
                showLedger = true
            } label: {
                HStack {
                    Text(L10n.string("ledger.open"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .themeTertiary()
                }
                .padding(14)
                .background { SettingsRowSurface() }
            }
            .buttonStyle(.plain)
        }
    }

    private var privacyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("privacy.title"))
            Text(L10n.string("privacy.body"))
                .font(.footnote)
                .themeSecondary()
            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("privacy.local"))
                        .font(.subheadline.weight(.medium))
                    Text(L10n.string("privacy.optionalSync"))
                        .font(.caption)
                        .themeTertiary()
                    Text(L10n.string("privacy.noAds"))
                        .font(.caption)
                        .themeTertiary()
                }
            }
        }
    }

    private var shortcutsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("shortcuts.title"))
            Text(L10n.string("shortcuts.body"))
                .font(.footnote)
                .themeSecondary()
            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("shortcuts.siri"))
                        .font(.subheadline)
                    Text(L10n.string("shortcuts.backTap"))
                        .font(.caption)
                        .themeTertiary()
                    Text(L10n.string("shortcuts.actionButton"))
                        .font(.caption)
                        .themeTertiary()
                    Text(L10n.string("shortcuts.applePay"))
                        .font(.caption)
                        .themeTertiary()
                    Text(L10n.string("shortcuts.widget"))
                        .font(.caption)
                        .themeTertiary()
                }
            }
        }
    }

    private var budgetBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("budget.title"))
            Text(L10n.string("budget.hint"))
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.string("budget.enabled"), isOn: $settings.budgetEnabled)

                    if settings.budgetEnabled {
                        TextField(L10n.string("budget.amount"), text: $budgetText)
                            .keyboardType(.decimalPad)
                            .glassField()
                            .onChange(of: budgetText) { _, newValue in
                                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                                if let value = Double(normalized), value > 0 {
                                    settings.budgetAmount = value
                                }
                            }

                        Picker(L10n.string("field.currency"), selection: $settings.budgetCurrency) {
                            ForEach(AppCurrency.allCases) { code in
                                Text(code.code).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var categoryBudgetBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("budget.categories"))
            Text(L10n.string("budget.categoriesHint"))
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories.filter { $0.kind.matches(.expense) }, id: \.id) { cat in
                        HStack(spacing: 10) {
                            Text(cat.displayName())
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            TextField(
                                L10n.string("budget.amount"),
                                text: Binding(
                                    get: { categoryBudgetTexts[cat.id] ?? "" },
                                    set: { newValue in
                                        categoryBudgetTexts[cat.id] = newValue
                                        let normalized = newValue
                                            .replacingOccurrences(of: ",", with: ".")
                                            .trimmingCharacters(in: .whitespaces)
                                        if normalized.isEmpty {
                                            settings.setCategoryBudget(nil, for: cat.id)
                                        } else if let value = Double(normalized), value > 0 {
                                            settings.setCategoryBudget(value, for: cat.id)
                                        }
                                    }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                            .glassField()
                        }
                    }
                }
            }
        }
    }

    private var reminderBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("reminder.title"))
            Text(L10n.string("reminder.hint"))
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.string("reminder.enabled"), isOn: $settings.reminderEnabled)

                    if settings.reminderEnabled {
                        Stepper(
                            value: $settings.reminderHour,
                            in: 0...23
                        ) {
                            Text(
                                String(
                                    format: L10n.string("reminder.hourFormat"),
                                    settings.reminderHour
                                )
                            )
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private var securityBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("lock.title"))
            Text(L10n.string("lock.hint"))
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                Toggle(AppLockService.biometryLabel, isOn: $settings.lockEnabled)
            }
        }
    }

    private var recurringBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("recurring.title"))
            Button {
                showRecurring = true
            } label: {
                HStack {
                    Text(L10n.string("recurring.manage"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .themeTertiary()
                }
                .padding(14)
                .background {
                    SettingsRowSurface()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var iCloudBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("icloud.title"))
            Text(DataStore.iCloudStatusMessage)
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                Toggle(L10n.string("icloud.prefer"), isOn: $settings.preferiCloudSync)
            }

            Text(L10n.string("icloud.restartNote"))
                .font(.caption2)
                .themeTertiary()
        }
    }

    private var ratesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("settings.ratesTitle"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rateLine(code: .usd))
                            Text(rateLine(code: .eur))
                            Text(rateLine(code: .rub))
                        }
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Button {
                            Task { await rates.refresh(force: true) }
                        } label: {
                            if rates.isRefreshing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.string("settings.ratesRefresh"))
                    }

                    Text(rates.ratesFootnote)
                        .font(.caption2)
                        .themeTertiary()
                }
            }
        }
    }

    private func rateLine(code: AppCurrency) -> String {
        let value = rates.bynPerUnit[code] ?? ExchangeRateStore.staticBynPerUnit[code] ?? 0
        let formatted = String(format: "%.4g", value)
        return "1 \(code.code) = \(formatted) BYN"
    }

    private func currencyBlock(
        title: String,
        subtitle: String,
        selection: Binding<AppCurrency>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: title)
            Text(subtitle)
                .font(.footnote)
                .themeTertiary()

            GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                VStack(spacing: 0) {
                    ForEach(AppCurrency.allCases) { code in
                        Button {
                            selection.wrappedValue = code
                        } label: {
                            HStack(spacing: 12) {
                                Text(code.displaySymbol)
                                    .font(.body.weight(.semibold).monospaced())
                                    .frame(width: 36, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                Text(code.localizedTitle)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if selection.wrappedValue == code {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if code != AppCurrency.allCases.last {
                            Divider().opacity(0.2).padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsRowSurface: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        AppTheme.continuousRect(AppTheme.cornerMedium)
            .fill(
                scheme == .dark
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AnyShapeStyle(Color.white.opacity(0.94))
            )
            .overlay {
                if scheme != .dark {
                    AppTheme.continuousRect(AppTheme.cornerMedium)
                        .strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                }
            }
    }
}
