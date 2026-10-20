import UIKit

/// User-selectable home-screen icons via `UIApplication.setAlternateIconName`.
enum AppIconOption: String, CaseIterable, Identifiable {
    case systemDefault = "default"
    case dark = "AppIcon-Dark"
    case clear = "AppIcon-Clear"

    var id: String { rawValue }

    /// `nil` restores the primary AppIcon from the asset catalog.
    var alternateIconName: String? {
        switch self {
        case .systemDefault: return nil
        case .dark, .clear: return rawValue
        }
    }

    var titleKey: String {
        switch self {
        case .systemDefault: return "settings.icon.default"
        case .dark: return "settings.icon.dark"
        case .clear: return "settings.icon.clear"
        }
    }

    var symbolName: String {
        switch self {
        case .systemDefault: return "app.fill"
        case .dark: return "moon.fill"
        case .clear: return "square.dashed"
        }
    }
}

@MainActor
enum AppIconSettings {
    private static let storageKey = "appIcon.preference"

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var current: AppIconOption {
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           let option = AppIconOption(rawValue: stored) {
            return option
        }
        // Infer from system if possible
        if let name = UIApplication.shared.alternateIconName,
           let option = AppIconOption(rawValue: name) {
            return option
        }
        return .systemDefault
    }

    static func apply(_ option: AppIconOption) async throws {
        guard supportsAlternateIcons || option == .systemDefault else {
            // Simulator / older — still persist preference
            UserDefaults.standard.set(option.rawValue, forKey: storageKey)
            return
        }

        let target = option.alternateIconName
        let active = UIApplication.shared.alternateIconName
        if active == target {
            UserDefaults.standard.set(option.rawValue, forKey: storageKey)
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(target) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    UserDefaults.standard.set(option.rawValue, forKey: storageKey)
                    continuation.resume()
                }
            }
        }
    }

    /// Re-apply persisted choice on launch (e.g. after reinstall of preference).
    static func syncFromStorage() {
        let option = current
        let target = option.alternateIconName
        guard UIApplication.shared.alternateIconName != target else { return }
        UIApplication.shared.setAlternateIconName(target) { _ in }
    }
}
