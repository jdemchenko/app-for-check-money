import Combine
import Foundation
import WatchKit

/// Watch dictation without `import Speech` — Speech is not a watchOS Swift module
/// like on iOS. Uses WatchKit system text input (dictation / scribble).
@MainActor
final class WatchSpeechRecognizer: ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var isAuthorized = true
    /// True while system dictation UI (or SwiftUI fallback sheet) should be up.
    @Published var presentSystemDictation = false

    var onUtteranceFinished: ((String) -> Void)?

    private var didPresentWatchKit = false

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    var isListening: Bool { status == .listening || presentSystemDictation }

    func prepare() async {
        status = .idle
        isAuthorized = true
    }

    /// Begin dictation via WatchKit text input (includes dictation mic).
    func start() {
        guard !presentSystemDictation else { return }
        transcript = ""
        didPresentWatchKit = false
        status = .listening
        presentSystemDictation = true
        presentWatchTextInput()
    }

    func stop() {
        // WatchKit sheet owns the session until the user finishes speaking.
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

    /// Whether SwiftUI should show its TextField fallback (WatchKit controller missing).
    var needsSwiftUIFallback: Bool {
        presentSystemDictation && !didPresentWatchKit
    }

    private func presentWatchTextInput() {
        guard let controller = Self.activeInterfaceController() else {
            // WatchDictateView will show a TextField sheet via needsSwiftUIFallback.
            return
        }
        didPresentWatchKit = true
        let suggestions: [String] = isRussian
            ? ["еда", "транспорт", "кофе"]
            : ["food", "transport", "coffee"]
        controller.presentTextInputController(
            withSuggestions: suggestions,
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
