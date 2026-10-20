import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognizer: ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var isAuthorized = false

    /// Fired once when listening ends with the final transcript (silence timeout, stop, or isFinal).
    var onUtteranceFinished: ((String) -> Void)?

    /// When false (hold-to-talk), only an explicit `stop()` ends the utterance — no silence timer.
    var allowsSilenceFinish = true

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var silenceTask: Task<Void, Never>?
    private var didEmitFinished = false
    private var tapInstalled = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private let silenceNanoseconds: UInt64 = 1_600_000_000

    var isAvailable: Bool {
        let auth = SFSpeechRecognizer.authorizationStatus()
        guard auth != .denied, auth != .restricted else { return false }
        return recognizer?.isAvailable == true
    }

    var isListening: Bool { status == .listening }

    init() {
        let locale = Locale.current
        let code = locale.language.languageCode?.identifier ?? "en"
        let speechLocale = code.hasPrefix("ru")
            ? Locale(identifier: "ru-RU")
            : Locale(identifier: "en-US")
        recognizer = SFSpeechRecognizer(locale: speechLocale)
        if recognizer == nil {
            status = .unavailable(L10n.string("voice.unsupported"))
        }
        observeSessionEvents()
    }

    func prepare() async {
        guard recognizer != nil else {
            status = .unavailable(L10n.string("voice.unsupported"))
            return
        }

        status = .requestingPermission
        let speechOk = await requestSpeechAuth()
        let micOk = await requestMicAuth()

        isAuthorized = speechOk && micOk
        if !isAuthorized {
            status = .unavailable(L10n.string("voice.permissionDenied"))
        } else {
            status = .idle
        }
    }

    func start() {
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable(L10n.string("voice.unsupported"))
            return
        }
        guard isAuthorized else {
            Task {
                await prepare()
                if isAuthorized { start() }
            }
            return
        }

        // Full reset of any previous attempt before activating again.
        cancelSilenceWatch()
        teardownEngine(deactivateSession: true)
        task?.cancel()
        task = nil
        request = nil
        transcript = ""
        didEmitFinished = false

        do {
            try activateSessionForSpeech()
        } catch {
            status = .failed(Self.friendlySessionError(error))
            return
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false
        }

        let input = audioEngine.inputNode
        // Format must be read after session activation; Simulator can briefly report 0 Hz.
        let format = Self.inputFormat(for: input)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardownEngine(deactivateSession: true)
            status = .failed(L10n.string("voice.sessionFailed"))
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            teardownEngine(deactivateSession: true)
            status = .failed(Self.friendlySessionError(error))
            return
        }

        self.audioEngine = audioEngine
        self.request = request
        status = .listening

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if !self.transcript.isEmpty {
                        self.scheduleSilenceFinish()
                    }
                    if result.isFinal {
                        self.finishUtterance()
                    }
                }
                if let error {
                    let ns = error as NSError
                    // Cancellation after endAudio / stop is expected.
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 216 || ns.code == 203 {
                        return
                    }
                    if self.status == .listening {
                        self.status = .failed(error.localizedDescription)
                    }
                    self.cancelSilenceWatch()
                    self.teardownEngine(deactivateSession: true)
                }
            }
        }
    }

    /// User tapped stop — end and emit whatever we have.
    func stop() {
        finishUtterance()
    }

    func clearTranscript() {
        transcript = ""
    }

    // MARK: - Session

    /// Configure + activate AVAudioSession for SFSpeechRecognizer input.
    /// Previous category/options (e.g. `.record` + `.duckOthers`) commonly throw
    /// “Session activation failed” on device and Simulator.
    private func activateSessionForSpeech() throws {
        let session = AVAudioSession.sharedInstance()

        // Always release a prior activation before switching category.
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])

        // Avoid `.record` + `.duckOthers` (incompatible → “Session activation failed”).
        // Avoid Bluetooth HFP options here — they often fail activation on Simulator
        // when no HFP route exists. Device mics work with playAndRecord + defaultToSpeaker.
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker]
            )
        } catch {
            try session.setCategory(.record, mode: .measurement, options: [])
        }

        try? session.setPreferredSampleRate(44_100)
        try? session.setPreferredIOBufferDuration(0.01)

        do {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            // One retry after forced deactivate — handles sticky sessions.
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        }
    }

    private static func inputFormat(for input: AVAudioInputNode) -> AVAudioFormat {
        let hardware = input.outputFormat(forBus: 0)
        if hardware.sampleRate > 0, hardware.channelCount > 0 {
            return hardware
        }
        // Simulator / cold start fallback
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) ?? hardware
    }

    private static func friendlySessionError(_ error: Error) -> String {
        let ns = error as NSError
        // AVAudioSessionErrorCodeCannotStartPlaying / SessionActivationFailed often surface as this string.
        let text = ns.localizedDescription.lowercased()
        if text.contains("session activation failed")
            || text.contains("activating")
            || ns.code == 560_557_684 /* ' !act' SessionActivationFailed */
            || ns.domain == NSOSStatusErrorDomain {
            return L10n.string("voice.sessionFailed")
        }
        return ns.localizedDescription
    }

    // MARK: - Lifecycle helpers

    private func scheduleSilenceFinish() {
        guard allowsSilenceFinish else { return }
        cancelSilenceWatch()
        silenceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: silenceNanoseconds)
            guard !Task.isCancelled else { return }
            guard status == .listening else { return }
            finishUtterance()
        }
    }

    private func cancelSilenceWatch() {
        silenceTask?.cancel()
        silenceTask = nil
    }

    private func finishUtterance() {
        cancelSilenceWatch()
        request?.endAudio()
        teardownEngine(deactivateSession: true)
        task?.cancel()
        task = nil
        request = nil

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == .listening {
            status = .idle
        }
        guard !didEmitFinished else { return }
        didEmitFinished = true
        onUtteranceFinished?(text)
    }

    private func teardownEngine(deactivateSession: Bool) {
        if let engine = audioEngine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            if engine.isRunning {
                engine.stop()
            }
        }
        audioEngine = nil

        if deactivateSession {
            try? AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func observeSessionEvents() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // If we lose the input route mid-listen, stop cleanly so the next tap can retry.
                guard let self, self.isListening else { return }
                let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
                if inputs.isEmpty {
                    self.status = .failed(L10n.string("voice.sessionFailed"))
                    self.teardownEngine(deactivateSession: true)
                }
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            if isListening {
                cancelSilenceWatch()
                teardownEngine(deactivateSession: true)
                status = .idle
            }
        case .ended:
            // Leave idle — user taps mic again to resume (avoids surprise re-listen).
            break
        @unknown default:
            break
        }
    }

    private func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
