import Foundation
import WatchConnectivity

/// Watch-side store: Documents cache + WatchConnectivity. Phone SwiftData is source of truth.
@MainActor
final class WatchStore: NSObject, ObservableObject {
    static let shared = WatchStore()

    @Published private(set) var snapshot: WatchSnapshot = .empty
    @Published private(set) var isReachable = false
    @Published private(set) var lastSavedSummary: String?
    @Published var lastError: String?

    private var session: WCSession?

    private override init() {
        super.init()
        reloadFromDisk()
        activateSession()
    }

    func reloadFromDisk() {
        if let snap = LocalSyncStore.readSnapshot() {
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

    /// Persist locally and push to phone via WCSession (message + transferUserInfo).
    func saveFromVoice(_ draft: SharedVoiceDraft, defaultCurrency: SharedCurrencyCode) {
        guard let amount = draft.amount, amount > 0 else {
            lastError = "no-amount"
            return
        }
        let typeRaw = draft.typeRaw ?? "expense"
        let categoryId = draft.categoryId
            ?? snapshot.categories.first { $0.matchesType(typeRaw) }?.id
            ?? "other-expense"
        let currencyRaw = draft.currencyRaw ?? defaultCurrency.rawValue
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)

        let pending = WatchPendingAdd(
            amount: amount,
            categoryId: categoryId,
            note: note.isEmpty ? nil : note,
            currencyRaw: currencyRaw,
            typeRaw: typeRaw
        )
        applyPendingLocally(pending)
        sendPendingToPhone(pending)

        let code = SharedCurrencyCode(rawValue: currencyRaw) ?? .byn
        let sign = typeRaw == "income" ? "+" : "−"
        lastSavedSummary = sign + SharedMoneyFormat.currency(amount, code: code)
        lastError = nil
    }

    private func applyPendingLocally(_ pending: WatchPendingAdd) {
        do {
            try LocalSyncStore.appendPendingAdd(pending)

            var snap = snapshot
            let dto = SharedTransactionDTO(
                id: pending.id,
                amount: pending.amount,
                typeRaw: pending.typeRaw,
                categoryId: pending.categoryId,
                note: pending.note,
                date: pending.createdAt,
                createdAt: pending.createdAt,
                sourceRaw: "voice",
                currencyRaw: pending.currencyRaw
            )
            snap.recent.insert(dto, at: 0)
            if snap.recent.count > 20 { snap.recent = Array(snap.recent.prefix(20)) }
            if pending.typeRaw == "income" {
                snap.monthIncome += pending.amount
            } else {
                snap.todayExpense += pending.amount
                snap.monthExpense += pending.amount
            }
            snap.updatedAt = .now
            snapshot = snap
            try LocalSyncStore.writeSnapshot(snap)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func sendPendingToPhone(_ pending: WatchPendingAdd) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder.iso8601.encode(pending) else { return }
        let payload: [String: Any] = ["pendingAdd": data.base64EncodedString()]

        // Reliable queue even if phone is temporarily unreachable.
        session.transferUserInfo(payload)

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

    private func applySnapshotData(_ b64: String) {
        guard let data = Data(base64Encoded: b64),
              let snap = try? JSONDecoder.iso8601.decode(WatchSnapshot.self, from: data)
        else { return }
        snapshot = snap
        try? LocalSyncStore.writeSnapshot(snap)
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
            if let b64 = applicationContext["snapshot"] as? String {
                applySnapshotData(b64)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if let b64 = userInfo["snapshot"] as? String {
                applySnapshotData(b64)
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
