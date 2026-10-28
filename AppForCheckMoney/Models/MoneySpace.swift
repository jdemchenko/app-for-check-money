import Foundation
import SwiftData

/// Ledger scope. Default is a private on-device space.
/// Shared / family invite is a UX shell until paid Apple Developer + iCloud.
@Model
final class MoneySpace {
    @Attribute(.unique) var id: String
    var name: String
    /// `private` | `shared` (shared is local-only placeholder on Personal Team)
    var kindRaw: String
    var createdAt: Date
    /// Opaque invite token placeholder (never synced on Personal Team).
    var inviteCode: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        kind: SpaceKind = .privateSpace,
        createdAt: Date = .now,
        inviteCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.inviteCode = inviteCode
    }

    var kind: SpaceKind {
        get { SpaceKind(rawValue: kindRaw) ?? .privateSpace }
        set { kindRaw = newValue.rawValue }
    }

    var isSharedPlaceholder: Bool { kind == .shared }
}

enum SpaceKind: String, Codable, CaseIterable, Identifiable {
    case privateSpace = "private"
    case shared = "shared"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateSpace: return L10n.string("space.private")
        case .shared: return L10n.string("space.shared")
        }
    }
}

enum SpaceIDs {
    static let privateDefault = "space-private"
}
