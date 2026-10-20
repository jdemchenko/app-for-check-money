import Foundation

/// JSON snapshot + pending Watch adds in the App Group container (fallback: app Documents).
enum AppGroupStore {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: CheckMoneyAppGroup.id
        ) {
            return url
        }
        // Simulator / unsigned builds without App Group — still functional locally.
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CheckMoneyShared", isDirectory: true)
    }

    private static func ensureContainer() {
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
    }

    static var snapshotURL: URL {
        ensureContainer()
        return containerURL.appendingPathComponent(CheckMoneyAppGroup.snapshotFileName)
    }

    static var pendingURL: URL {
        ensureContainer()
        return containerURL.appendingPathComponent(CheckMoneyAppGroup.pendingWatchAddsFileName)
    }

    static func writeSnapshot(_ snapshot: WatchSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    static func readSnapshot() -> WatchSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? decoder.decode(WatchSnapshot.self, from: data)
    }

    static func readPendingAdds() -> [WatchPendingAdd] {
        guard let data = try? Data(contentsOf: pendingURL),
              let items = try? decoder.decode([WatchPendingAdd].self, from: data)
        else { return [] }
        return items
    }

    static func writePendingAdds(_ items: [WatchPendingAdd]) throws {
        let data = try encoder.encode(items)
        try data.write(to: pendingURL, options: [.atomic])
    }

    static func appendPendingAdd(_ item: WatchPendingAdd) throws {
        var all = readPendingAdds()
        all.append(item)
        try writePendingAdds(all)
    }

    static func clearPendingAdds(ids: Set<String>) throws {
        let left = readPendingAdds().filter { !ids.contains($0.id) }
        try writePendingAdds(left)
    }
}
