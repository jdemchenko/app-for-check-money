import Foundation
import WatchConnectivity

/// Watch-side store: App Group snapshot + WatchConnectivity for live updates / pending adds.
@MainActor
final class WatchStore: NSObject, ObservableObject {
    static let shared = WatchStore()

    @Published private(set) var snapshot: WatchSnapshot = .empty
    @Published private(set) var isReachable = false
    @Published var lastError: String?

    private var session: WCSession?

    private override init() {
        super.init()
        reloadFromDisk()
        activateSession()
    }

    func reloadFromDisk() {
        if let snap = AppGroupStore.readSnapshot() {
            snapshot = snap
        } else if snapshot.categories.isEmpty {
            snapshot = .empty
        }
    }

    func requestRefresh() {
        reloadFromDisk()
        guard let session, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(["requestSnapshot": true], replyHandler: { [weak self] _ in
                Task { @MainActor in self?.reloadFromDisk() }
            }, errorHandler: { _ in })
        }
    }

    /// Persist locally and notify the phone.
    func addExpense(amount: Double, categoryId: String, note: String?, currency: SharedCurrencyCode) {
        let pending = WatchPendingAdd(
            amount: amount,
            categoryId: categoryId,
            note: note,
            currencyRaw: currency.rawValue
        )
        do {
            try AppGroupStore.appendPendingAdd(pending)

            // Optimistic recent row for immediate UI feedback.
            var snap = snapshot
            let dto = SharedTransactionDTO(
                id: pending.id,
                amount: pending.amount,
                typeRaw: "expense",
                categoryId: pending.categoryId,
                note: pending.note,
                date: pending.createdAt,
                createdAt: pending.createdAt,
                sourceRaw: "manual",
                currencyRaw: pending.currencyRaw
            )
            snap.recent.insert(dto, at: 0)
            if snap.recent.count > 20 { snap.recent = Array(snap.recent.prefix(20)) }
            snap.todayExpense += amount
            snap.monthExpense += amount
            snap.updatedAt = .now
            snapshot = snap
            try AppGroupStore.writeSnapshot(snap)

            sendPendingToPhone(pending)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func sendPendingToPhone(_ pending: WatchPendingAdd) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder.iso8601.encode(pending) else { return }
        let payload: [String: Any] = ["pendingAdd": data.base64EncodedString()]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { _ in }, errorHandler: { _ in
                try? session.updateApplicationContext(payload)
            })
        } else {
            try? session.updateApplicationContext(payload)
        }
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
            reloadFromDisk()
            if activationState == .activated {
                requestRefresh()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            if session.isReachable { requestRefresh() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let b64 = applicationContext["snapshot"] as? String,
               let data = Data(base64Encoded: b64),
               let snap = try? JSONDecoder.iso8601.decode(WatchSnapshot.self, from: data) {
                snapshot = snap
                try? AppGroupStore.writeSnapshot(snap)
            }
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
