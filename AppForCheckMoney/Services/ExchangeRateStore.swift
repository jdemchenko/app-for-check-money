import Foundation
import Combine

/// Live FX from myfin.by (НБРБ board via `api.myfin.by/currency/nbrb`).
/// Used only for **display totals** — never rewrites stored per-tx amounts.
@MainActor
final class ExchangeRateStore: ObservableObject {
    static let shared = ExchangeRateStore()

    /// Cache TTL before a background refresh is attempted.
    static let cacheTTL: TimeInterval = 3 * 60 * 60 // 3 hours

    private static let cacheRatesKey = "fx.myfin.bynPerUnit"
    private static let cacheDateKey = "fx.myfin.updatedAt"
    private static let endpoint = URL(string: "https://api.myfin.by/currency/nbrb")!

    /// Built-in fallback when network + disk cache are unavailable.
    nonisolated static let staticBynPerUnit: [AppCurrency: Double] = [
        .byn: 1.0,
        .usd: 3.25,
        .eur: 3.55,
        .rub: 0.036,
        .gbp: 4.15,
    ]

    /// Thread-safe snapshot for `CurrencyConverter.convert` (may run off MainActor).
    nonisolated private static let snapshotLock = NSLock()
    nonisolated(unsafe) private static var rateSnapshot: [AppCurrency: Double] = staticBynPerUnit

    nonisolated static func currentRates() -> [AppCurrency: Double] {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return rateSnapshot
    }

    nonisolated private static func publishSnapshot(_ rates: [AppCurrency: Double]) {
        snapshotLock.lock()
        rateSnapshot = rates
        snapshotLock.unlock()
    }

    @Published private(set) var bynPerUnit: [AppCurrency: Double]
    @Published private(set) var updatedAt: Date?
    /// `live` | `cache` | `static`
    @Published private(set) var sourceKind: SourceKind
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    enum SourceKind: String {
        case live
        case cache
        case staticFallback = "static"
    }

    private init() {
        if let cached = Self.loadCache() {
            bynPerUnit = cached.rates
            updatedAt = cached.date
            sourceKind = .cache
            Self.publishSnapshot(cached.rates)
        } else {
            bynPerUnit = Self.staticBynPerUnit
            updatedAt = nil
            sourceKind = .staticFallback
            Self.publishSnapshot(Self.staticBynPerUnit)
        }
    }

    var ratesFootnote: String {
        switch sourceKind {
        case .live, .cache:
            let when = updatedAt.map { Self.formatUpdated($0) } ?? "—"
            return String(format: L10n.string("settings.ratesLive"), when)
        case .staticFallback:
            return L10n.string("settings.ratesStaticFallback")
        }
    }

    /// Refresh when cache is missing/stale. Safe to call often.
    func refreshIfNeeded(force: Bool = false) {
        if isRefreshing { return }
        if !force, let updatedAt, Date().timeIntervalSince(updatedAt) < Self.cacheTTL {
            return
        }
        Task { await refresh(force: force) }
    }

    func refresh(force: Bool = false) async {
        if isRefreshing { return }
        if !force, let updatedAt, Date().timeIntervalSince(updatedAt) < Self.cacheTTL,
           sourceKind == .live || sourceKind == .cache {
            return
        }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: Self.endpoint)
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let rates = try Self.parseNbrb(data)
            applyRates(rates, kind: .live, at: .now)
            Self.saveCache(rates: rates, date: .now)
        } catch {
            lastError = error.localizedDescription
            if updatedAt != nil {
                sourceKind = .cache
            } else {
                applyRates(Self.staticBynPerUnit, kind: .staticFallback, at: nil)
            }
        }
    }

    private func applyRates(_ rates: [AppCurrency: Double], kind: SourceKind, at: Date?) {
        bynPerUnit = rates
        updatedAt = at
        sourceKind = kind
        Self.publishSnapshot(rates)
    }

    // MARK: - Parse

    /// `{"today":{"date":…,"currencies":{"usd":{"rate":"2.995"},…}}}`
    nonisolated static func parseNbrb(_ data: Data) throws -> [AppCurrency: Double] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let today = root?["today"] as? [String: Any]
        let currencies = today?["currencies"] as? [String: Any]
            ?? root?["currencies"] as? [String: Any]
        guard let currencies else {
            throw URLError(.cannotParseResponse)
        }

        var out: [AppCurrency: Double] = [.byn: 1.0]
        for code in AppCurrency.allCases where code != .byn {
            guard let entry = currencies[code.rawValue] as? [String: Any] else { continue }
            let raw = entry["rate"]
            let value: Double?
            if let s = raw as? String {
                value = Double(s.replacingOccurrences(of: ",", with: "."))
            } else if let n = raw as? Double {
                value = n
            } else if let n = raw as? NSNumber {
                value = n.doubleValue
            } else {
                value = nil
            }
            if let value, value > 0 {
                out[code] = value
            }
        }
        guard out[.usd] != nil, out[.eur] != nil else {
            throw URLError(.cannotParseResponse)
        }
        if out[.rub] == nil {
            out[.rub] = staticBynPerUnit[.rub]!
        }
        if out[.gbp] == nil {
            out[.gbp] = staticBynPerUnit[.gbp]!
        }
        return out
    }

    // MARK: - Disk cache

    private static func loadCache() -> (rates: [AppCurrency: Double], date: Date)? {
        let defaults = UserDefaults.standard
        guard let raw = defaults.dictionary(forKey: cacheRatesKey) as? [String: Double],
              let interval = defaults.object(forKey: cacheDateKey) as? TimeInterval
        else { return nil }
        var rates: [AppCurrency: Double] = [.byn: 1]
        for (key, value) in raw {
            guard let code = AppCurrency(rawValue: key), value > 0 else { continue }
            rates[code] = value
        }
        guard rates[.usd] != nil else { return nil }
        return (rates, Date(timeIntervalSince1970: interval))
    }

    private static func saveCache(rates: [AppCurrency: Double], date: Date) {
        var raw: [String: Double] = [:]
        for (code, value) in rates {
            raw[code.rawValue] = value
        }
        let defaults = UserDefaults.standard
        defaults.set(raw, forKey: cacheRatesKey)
        defaults.set(date.timeIntervalSince1970, forKey: cacheDateKey)
    }

    private static func formatUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
