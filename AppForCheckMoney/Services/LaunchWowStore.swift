import Foundation
import Combine
import SwiftUI

/// Cold-launch brand morph + one light return pulse per process.
/// Never blocks Face ID — AppRootHost starts wow only when unlocked (or lock off).
@MainActor
final class LaunchWowStore: ObservableObject {
    static let shared = LaunchWowStore()

    enum Phase: Equatable {
        case idle
        case cold
        case returning
    }

    @Published private(set) var phase: Phase = .idle
    /// Home listens — one-shot balance reveal / mic pulse after return wow.
    @Published private(set) var homePulseToken: Int = 0

    private var coldPlayedThisProcess = false
    private var returnPlayedThisProcess = false
    private var sawBackgroundThisProcess = false
    private var pendingAfterUnlock: Phase?

    private init() {}

    /// Call when the UI is free to show wow (unlocked, or lock disabled).
    func considerColdLaunch(reduceMotion: Bool) {
        guard !coldPlayedThisProcess else { return }
        if reduceMotion {
            coldPlayedThisProcess = true
            phase = .idle
            return
        }
        if phase != .idle { return }
        coldPlayedThisProcess = true
        phase = .cold
    }

    /// Face ID still up — remember cold so we play after unlock.
    func deferColdUntilUnlock() {
        guard !coldPlayedThisProcess else { return }
        pendingAfterUnlock = .cold
    }

    func onUnlocked(reduceMotion: Bool) {
        if let pending = pendingAfterUnlock {
            pendingAfterUnlock = nil
            if pending == .cold {
                considerColdLaunch(reduceMotion: reduceMotion)
                if reduceMotion {
                    notifyHomeReadyIfNeeded()
                }
            } else if pending == .returning {
                playReturn(reduceMotion: reduceMotion)
            }
        }
    }

    func onBackground() {
        sawBackgroundThisProcess = true
    }

    /// One light return wow per process after leaving background — not every foreground.
    func onBecameActive(unlocked: Bool, reduceMotion: Bool) {
        guard sawBackgroundThisProcess else { return }
        guard !returnPlayedThisProcess else { return }
        guard coldPlayedThisProcess else { return }
        guard phase == .idle else { return }
        if !unlocked {
            pendingAfterUnlock = .returning
            return
        }
        playReturn(reduceMotion: reduceMotion)
    }

    func finishOverlay() {
        // Cold + return both hand off to Home hero (count-up / mic pulse).
        let handoff = phase == .cold || phase == .returning
        phase = .idle
        if handoff {
            homePulseToken &+= 1
        }
    }

    private func playReturn(reduceMotion: Bool) {
        returnPlayedThisProcess = true
        phase = .idle
        // No second brand splash — Home does a ~0.6s balance reveal + mic pulse.
        homePulseToken &+= 1
        _ = reduceMotion
    }

    /// When Reduce Motion skips the overlay, still nudge Home once.
    func notifyHomeReadyIfNeeded() {
        guard coldPlayedThisProcess, homePulseToken == 0 else { return }
        homePulseToken &+= 1
    }
}
