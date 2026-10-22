import Foundation
import Combine

/// Holds text shared into the app (URL scheme, document open, clipboard paste).
@MainActor
final class IncomingDraftStore: ObservableObject {
    static let shared = IncomingDraftStore()

    @Published var pendingText: String?

    private init() {}

    func consume() -> String? {
        let value = pendingText
        pendingText = nil
        return value
    }

    func offer(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingText = trimmed
    }

    /// `checkmoney://draft?text=…` or `checkmoney://add?text=…`
    func handle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "checkmoney" else { return false }
        let host = (url.host ?? url.path).lowercased()
        let isDraft = host.contains("draft") || host.contains("add") || url.path.contains("draft")
        guard isDraft || url.query?.contains("text=") == true else {
            if let text = queryValue("text", in: url) {
                offer(text)
                return true
            }
            return false
        }
        if let text = queryValue("text", in: url) {
            offer(text)
            return true
        }
        return false
    }

    func handleOpenedFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            loadFile(url)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        loadFile(url)
    }

    private func loadFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: String.Encoding(rawValue: 2145))
        else { return }
        if ext == "csv" {
            // History import owns CSV; stash raw for CSVImport path via notification name.
            NotificationCenter.default.post(
                name: .checkMoneyImportCSVText,
                object: text
            )
            return
        }
        offer(text)
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value?
            .removingPercentEncoding
    }
}

extension Notification.Name {
    static let checkMoneyImportCSVText = Notification.Name("checkMoneyImportCSVText")
}
