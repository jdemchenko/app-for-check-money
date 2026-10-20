import Combine
import Foundation
import WatchKit

/// System WatchKit dictation only — no Speech module on watchOS.
/// Empty suggestions + `.plain` → straight to the mic (no scribble/emoji chooser).
/// Do **not** use `presentTextInputController(withSuggestionsForLanguage:)` — Apple docs:
/// that API never goes straight to dictation (shows language switching UI).
/// Dictation language follows Watch/Siri (enable RU + EN there for auto multilingual ASR).
@MainActor
final class WatchSpeechRecognizer: ObservableObject {
    enum Status: Equatable {
        case idle
        case listening
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var isAuthorized = true
    @Published var presentSystemDictation = false

    var onUtteranceFinished: ((String) -> Void)?

    private var didPresentWatchKit = false

    var isListening: Bool { status == .listening || presentSystemDictation }

    func prepare() async {
        status = .idle
        isAuthorized = true
    }

    /// Tap mic → open system dictation immediately.
    func start() {
        guard !presentSystemDictation else { return }
        transcript = ""
        didPresentWatchKit = false
        status = .listening
        presentSystemDictation = true
        presentWatchTextInput()
    }

    func stop() {
        if status == .listening, !presentSystemDictation {
            status = .idle
        }
    }

    func complete(with text: String) {
        presentSystemDictation = false
        didPresentWatchKit = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = trimmed
        status = .idle
        onUtteranceFinished?(trimmed)
    }

    func cancelPresentation() {
        presentSystemDictation = false
        didPresentWatchKit = false
        if transcript.isEmpty {
            status = .idle
        }
    }

    var needsSwiftUIFallback: Bool {
        presentSystemDictation && !didPresentWatchKit
    }

    private func presentWatchTextInput() {
        guard let controller = Self.activeInterfaceController() else {
            return
        }
        didPresentWatchKit = true
        // nil suggestions + plain → dictation-first (Apple / WatchKit contract).
        controller.presentTextInputController(
            withSuggestions: nil,
            allowedInputMode: .plain
        ) { [weak self] results in
            Task { @MainActor in
                let text = (results?.first as? String) ?? ""
                self?.complete(with: text)
            }
        }
    }

    private static func activeInterfaceController() -> WKInterfaceController? {
        let ext = WKExtension.shared()
        return ext.visibleInterfaceController ?? ext.rootInterfaceController
    }
}
