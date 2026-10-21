import Foundation
import LocalAuthentication

enum AppLockService {
    static var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return L10n.string("lock.faceID")
        case .touchID: return L10n.string("lock.touchID")
        case .opticID: return L10n.string("lock.opticID")
        default: return L10n.string("lock.passcode")
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10n.string("common.cancel")
        var error: NSError?
        // Prefer biometrics+passcode fallback.
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics
        guard context.canEvaluatePolicy(policy, error: &error) else {
            return false
        }
        return await withCheckedContinuation { cont in
            context.evaluatePolicy(policy, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
}
