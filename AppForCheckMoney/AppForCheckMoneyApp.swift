import SwiftUI
import SwiftData

@main
struct AppForCheckMoneyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try DataStore.makeContainer()
        } catch {
            container = try! ModelContainer(
                for: MoneyTransaction.self, MoneyCategory.self, RecurringRule.self,
                    MoneyAccount.self, MoneyGoal.self, MoneyDebt.self, MoneySpace.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        SeedData.ensureDefaults(in: container.mainContext)
        _ = RecurringEngine.applyDue(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            AppRootHost()
                .environmentObject(AppSettingsStore.shared)
                .onOpenURL { url in
                    if IncomingDraftStore.shared.handle(url: url) { return }
                    IncomingDraftStore.shared.handleOpenedFile(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        _ = IncomingDraftStore.shared.handle(url: url)
                    }
                }
        }
        .modelContainer(container)
    }
}

/// Owns lock, onboarding, launch wow, WCSession, recurring catch-up, widget snapshot.
private struct AppRootHost: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettingsStore

    @Query private var transactions: [MoneyTransaction]
    @Query private var recurringRules: [RecurringRule]
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @ObservedObject private var launchWow = LaunchWowStore.shared

    @State private var unlocked = false

    private var isUnlocked: Bool { !settings.lockEnabled || unlocked }

    var body: some View {
        ZStack {
            RootTabView()
                .environment(\.launchHomePulseToken, launchWow.homePulseToken)

            if settings.lockEnabled && !unlocked {
                AppLockGate { unlocked = true }
                    .transition(.opacity)
                    .zIndex(2)
            }

            if !settings.onboardingDone {
                OnboardingView { settings.onboardingDone = true }
                    .transition(.opacity)
                    .zIndex(3)
            }

            // Cold brand morph only — never covers Face ID (lock sits under / before this).
            if isUnlocked, launchWow.phase == .cold {
                LaunchWowOverlay(mode: .cold) {
                    launchWow.finishOverlay()
                }
                .transition(.opacity)
                .zIndex(4)
            }
        }
        .onAppear {
            if !settings.lockEnabled {
                unlocked = true
                launchWow.considerColdLaunch(reduceMotion: reduceMotion)
            } else {
                launchWow.deferColdUntilUnlock()
            }
            SeedData.ensureLedgerDefaults(in: modelContext)
            Task { @MainActor in
                PhoneWatchSync.shared.start(modelContext: modelContext)
                await ReminderService.apply(
                    enabled: settings.reminderEnabled,
                    hour: settings.reminderHour
                )
                await ReminderService.scheduleRecurringDayBefore(rules: recurringRules)
            }
            publishWidget()
        }
        .onChange(of: unlocked) { _, isOn in
            if isOn {
                launchWow.onUnlocked(reduceMotion: reduceMotion)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if settings.lockEnabled { unlocked = false }
                launchWow.onBackground()
                publishWidget()
            case .active:
                _ = RecurringEngine.applyDue(in: modelContext)
                PhoneWatchSync.shared.refreshAfterForeground()
                Task {
                    await ReminderService.scheduleRecurringDayBefore(rules: recurringRules)
                }
                launchWow.onBecameActive(unlocked: isUnlocked, reduceMotion: reduceMotion)
                publishWidget()
            default:
                break
            }
        }
        .onChange(of: recurringRules.count) { _, _ in
            Task { await ReminderService.scheduleRecurringDayBefore(rules: recurringRules) }
        }
        .onChange(of: settings.lockEnabled) { _, enabled in
            unlocked = !enabled
            if !enabled {
                launchWow.onUnlocked(reduceMotion: reduceMotion)
            }
        }
        .onChange(of: transactions.count) { _, _ in
            publishWidget()
        }
    }

    private func publishWidget() {
        WidgetSnapshotStore.publish(
            transactions: transactions,
            displayCurrency: currencySettings.displayCurrency,
            settings: settings,
            accounts: accounts
        )
    }
}
