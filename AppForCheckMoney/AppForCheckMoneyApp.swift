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

/// Owns lock, onboarding, WCSession, recurring catch-up, widget snapshot.
private struct AppRootHost: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: AppSettingsStore

    @Query private var transactions: [MoneyTransaction]
    @Query private var recurringRules: [RecurringRule]
    @Query(sort: \MoneyAccount.sortOrder) private var accounts: [MoneyAccount]
    @ObservedObject private var currencySettings = CurrencySettings.shared

    @State private var unlocked = false

    var body: some View {
        ZStack {
            RootTabView()

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
        }
        .onAppear {
            if !settings.lockEnabled { unlocked = true }
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if settings.lockEnabled { unlocked = false }
                publishWidget()
            case .active:
                _ = RecurringEngine.applyDue(in: modelContext)
                PhoneWatchSync.shared.refreshAfterForeground()
                Task {
                    await ReminderService.scheduleRecurringDayBefore(rules: recurringRules)
                }
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
