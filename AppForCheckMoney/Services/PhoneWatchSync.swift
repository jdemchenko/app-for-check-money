import Foundation
import SwiftData
import WatchConnectivity

/// Phone-side sync: SwiftData glance snapshot → Documents cache + WatchConnectivity
/// when the Watch companion is installed. Soft-fails if Watch app is missing.
@MainActor
final class PhoneWatchSync: NSObject, ObservableObject {
    static let shared = PhoneWatchSync()

    @Published private(set) var lastPushAt: Date?
    @Published private(set) var isWatchReachable = false
    @Published private(set) var isWatchAppInstalled = false

    private var modelContext: ModelContext?
    private var session: WCSession?
    private var loggedMissingWatchApp = false

    private override init() {
        super.init()
    }

    func start(modelContext: ModelContext) {
        self.modelContext = modelContext
        guard WCSession.isSupported() else {
            pushSnapshot()
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        refreshWatchInstallState()
        pushSnapshot()
        mergePendingFromWatch()
    }

    /// Call after local saves so Watch glance stays fresh.
    func pushSnapshot() {
        guard let modelContext else { return }
        do {
            let snapshot = try buildSnapshot(in: modelContext)
            try? LocalSyncStore.writeSnapshot(snapshot)
            lastPushAt = .now
            pushContextIfWatchInstalled(snapshot)
        } catch {
            #if DEBUG
            print("PhoneWatchSync push failed: \(error)")
            #endif
        }
    }

    func mergePendingFromWatch() {
        guard let modelContext else { return }
        let pending = LocalSyncStore.readPendingAdds()
        guard !pending.isEmpty else { return }

        var mergedIds = Set<String>()
        for item in pending {
            let pendingId = item.id
            let existing = FetchDescriptor<MoneyTransaction>(
                predicate: #Predicate { $0.id == pendingId }
            )
            if let found = try? modelContext.fetch(existing), !found.isEmpty {
                mergedIds.insert(pendingId)
                continue
            }
            let txType: TransactionType = item.typeRaw == "income" ? .income : .expense
            let tx = MoneyTransaction(
                id: pendingId,
                amount: item.amount,
                type: txType,
                categoryId: item.categoryId,
                note: item.note,
                date: item.createdAt,
                createdAt: item.createdAt,
                source: .voice,
                currency: AppCurrency.parse(item.currencyRaw)
            )
            modelContext.insert(tx)
            mergedIds.insert(pendingId)
        }
        try? modelContext.save()
        try? LocalSyncStore.clearPendingAdds(ids: mergedIds)
        pushSnapshot()
    }

    private func ingestPendingAdd(_ add: WatchPendingAdd) {
        try? LocalSyncStore.appendPendingAdd(add)
        mergePendingFromWatch()
    }

    private func refreshWatchInstallState() {
        guard let session else {
            isWatchAppInstalled = false
            return
        }
        #if os(iOS)
        isWatchAppInstalled = session.isWatchAppInstalled
        isWatchReachable = session.isReachable
        #else
        isWatchAppInstalled = false
        #endif
    }

    private func pushContextIfWatchInstalled(_ snapshot: WatchSnapshot) {
        guard let session, session.activationState == .activated else { return }
        #if os(iOS)
        refreshWatchInstallState()
        guard session.isWatchAppInstalled else {
            if !loggedMissingWatchApp {
                loggedMissingWatchApp = true
                #if DEBUG
                print("PhoneWatchSync: Watch companion not on Watch yet — skipping WCSession. After AppForCheckMoney→iPhone Run (Build: Watch companion OK), open Watch app → Available Apps → CheckMoney.")
                #endif
            }
            return
        }
        #endif
        guard let data = try? JSONEncoder.iso8601.encode(snapshot) else { return }
        let payload: [String: Any] = [
            "snapshot": data.base64EncodedString(),
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
        ]
        // Snapshot = latest-wins via applicationContext (not a transferUserInfo flood).
        try? session.updateApplicationContext(payload)
    }

    private func buildSnapshot(in context: ModelContext) throws -> WatchSnapshot {
        let txs = try context.fetch(
            FetchDescriptor<MoneyTransaction>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        let cats = try context.fetch(
            FetchDescriptor<MoneyCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        let display = CurrencySettings.shared.displayCurrency
        let cal = Calendar.current
        let now = Date.now
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let dayStart = cal.startOfDay(for: now)

        var income = 0.0
        var expense = 0.0
        var todayExpense = 0.0
        for tx in txs {
            let converted = tx.amountIn(display)
            if tx.date >= monthStart {
                if tx.type == .income { income += converted }
                else { expense += converted }
            }
            if tx.type == .expense, tx.date >= dayStart {
                todayExpense += converted
            }
        }

        let categoryDTOs: [SharedCategoryDTO] = cats.map { $0.asSharedDTO }

        let recent = Array(txs.prefix(12)).map { tx in
            SharedTransactionDTO(
                id: tx.id,
                amount: tx.amount,
                typeRaw: tx.typeRaw,
                categoryId: tx.categoryId,
                note: tx.note,
                date: tx.date,
                createdAt: tx.createdAt,
                sourceRaw: tx.sourceRaw,
                currencyRaw: tx.currencyRaw
            )
        }

        return WatchSnapshot(
            updatedAt: .now,
            displayCurrencyRaw: display.rawValue,
            monthIncome: income,
            monthExpense: expense,
            todayExpense: todayExpense,
            categories: categoryDTOs.isEmpty ? SharedSeed.defaultExpenseCategories : categoryDTOs,
            recent: recent
        )
    }
}

extension PhoneWatchSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            refreshWatchInstallState()
            if activationState == .activated {
                pushSnapshot()
                mergePendingFromWatch()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshWatchInstallState()
            if session.isReachable {
                pushSnapshot()
                mergePendingFromWatch()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasInstalled = isWatchAppInstalled
            refreshWatchInstallState()
            if isWatchAppInstalled {
                loggedMissingWatchApp = false
                if !wasInstalled {
                    pushSnapshot()
                }
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            if let b64 = message["pendingAdd"] as? String,
               let data = Data(base64Encoded: b64),
               let add = try? JSONDecoder.iso8601.decode(WatchPendingAdd.self, from: data) {
                ingestPendingAdd(add)
                replyHandler(["ok": true])
                return
            }
            if message["requestSnapshot"] as? Bool == true {
                pushSnapshot()
                replyHandler(["ok": true])
                return
            }
            replyHandler(["ok": false])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let b64 = applicationContext["pendingAdd"] as? String,
               let data = Data(base64Encoded: b64),
               let add = try? JSONDecoder.iso8601.decode(WatchPendingAdd.self, from: data) {
                ingestPendingAdd(add)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if let b64 = userInfo["pendingAdd"] as? String,
               let data = Data(base64Encoded: b64),
               let add = try? JSONDecoder.iso8601.decode(WatchPendingAdd.self, from: data) {
                ingestPendingAdd(add)
                return
            }
            // Snapshot pushed via transferUserInfo — ignore on phone.
        }
    }
}

extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
