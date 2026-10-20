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
    private var releaseTailTask: Task<Void, Never>?
    private var didEmitFinished = false
    private var tapInstalled = false
    private var sessionWarm = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private let silenceNanoseconds: UInt64 = 1_600_000_000
    /// After finger-up: keep the recognition task alive briefly so trailing words / `isFinal` can land.
    private let releaseTailNanoseconds: UInt64 = 450_000_000

    private var lastPartial = ""
    private var finalText: String?

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
            // Pre-warm AVAudioSession so the first hold doesn’t pay full activation cost.
            warmSessionIfNeeded()
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

        cancelSilenceWatch()
        cancelReleaseTail()
        // Soft reset: drop prior tap/task but keep the warm audio session.
        teardownEngine(deactivateSession: false)
        task?.cancel()
        task = nil
        request = nil
        transcript = ""
        lastPartial = ""
        finalText = nil
        didEmitFinished = false

        do {
            try ensureSessionActive()
        } catch {
            status = .failed(Self.friendlySessionError(error))
            return
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Prefer server for latency on continuous dictation when available.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false
        }

        let input = audioEngine.inputNode
        let format = Self.inputFormat(for: input)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardownEngine(deactivateSession: false)
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
            teardownEngine(deactivateSession: false)
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
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finalText = text
                        if !text.isEmpty {
                            self.transcript = text
                        }
                        // Final arrived — finish without waiting out the full tail.
                        self.emitFinishedAndCleanup()
                    } else {
                        self.lastPartial = text
                        self.transcript = text
                        if !text.isEmpty {
                            self.scheduleSilenceFinish()
                        }
                    }
                }
                if let error {
                    let ns = error as NSError
                    // Cancellation / no-speech after endAudio is expected during graceful stop.
                    if ns.domain == "kAFAssistantErrorDomain",
                       ns.code == 216 || ns.code == 203 || ns.code == 1110 {
                        if self.status == .listening || self.releaseTailTask != nil {
                            self.emitFinishedAndCleanup()
                        }
                        return
                    }
                    if self.status == .listening {
                        self.status = .failed(error.localizedDescription)
                    }
                    self.cancelSilenceWatch()
                    self.cancelReleaseTail()
                    self.teardownEngine(deactivateSession: false)
                }
            }
        }
    }

    /// Hold-to-talk finger-up: stop capturing audio, wait briefly for trailing partials / `isFinal`, then emit.
    func stop() {
        beginGracefulStop()
    }

    func clearTranscript() {
        transcript = ""
        lastPartial = ""
        finalText = nil
    }

    // MARK: - Session

    private func warmSessionIfNeeded() {
        guard !sessionWarm else { return }
        do {
            try activateSessionForSpeech(forceDeactivateFirst: false)
            sessionWarm = true
        } catch {
            // Non-fatal — `start()` will retry.
            sessionWarm = false
        }
    }

    private func ensureSessionActive() throws {
        if sessionWarm {
            // Cheap re-assert; avoid setActive(false) round-trip on every press.
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                return
            } catch {
                sessionWarm = false
            }
        }
        try activateSessionForSpeech(forceDeactivateFirst: false)
        sessionWarm = true
    }

    /// Configure + activate AVAudioSession for SFSpeechRecognizer input.
    private func activateSessionForSpeech(forceDeactivateFirst: Bool) throws {
        let session = AVAudioSession.sharedInstance()

        if forceDeactivateFirst {
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        }

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
        try? session.setPreferredIOBufferDuration(0.005)

        do {
            try session.setActive(true)
        } catch {
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
            sessionWarm = true
        }
    }

    private static func inputFormat(for input: AVAudioInputNode) -> AVAudioFormat {
        let hardware = input.outputFormat(forBus: 0)
        if hardware.sampleRate > 0, hardware.channelCount > 0 {
            return hardware
        }
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) ?? hardware
    }

    private static func friendlySessionError(_ error: Error) -> String {
        let ns = error as NSError
        let text = ns.localizedDescription.lowercased()
        if text.contains("session activation failed")
            || text.contains("activating")
            || ns.code == 560_557_684
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
            beginGracefulStop()
        }
    }

    private func cancelSilenceWatch() {
        silenceTask?.cancel()
        silenceTask = nil
    }

    private func cancelReleaseTail() {
        releaseTailTask?.cancel()
        releaseTailTask = nil
    }

    /// End mic input but leave the recognition task alive for a short flush window.
    private func beginGracefulStop() {
        cancelSilenceWatch()
        guard !didEmitFinished else { return }

        // Already in the tail window — don’t restart it.
        if releaseTailTask != nil {
            return
        }

        request?.endAudio()

        if let engine = audioEngine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            if engine.isRunning {
                engine.stop()
            }
        }
        // Keep `task` + `request` until emit — Apple delivers final/partial after endAudio.

        releaseTailTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: releaseTailNanoseconds)
            guard !Task.isCancelled else { return }
            emitFinishedAndCleanup()
        }
    }

    private func emitFinishedAndCleanup() {
        cancelSilenceWatch()
        cancelReleaseTail()

        let preferred: String = {
            if let finalText, !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return finalText
            }
            if !lastPartial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return lastPartial
            }
            return transcript
        }()
        let text = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = text

        task?.cancel()
        task = nil
        request = nil
        teardownEngine(deactivateSession: false)

        if case .failed = status {
            // keep failed UI state
        } else {
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
            sessionWarm = false
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
                guard let self, self.isListening else { return }
                let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
                if inputs.isEmpty {
                    self.status = .failed(L10n.string("voice.sessionFailed"))
                    self.cancelReleaseTail()
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
            if isListening || releaseTailTask != nil {
                cancelSilenceWatch()
                cancelReleaseTail()
                teardownEngine(deactivateSession: true)
                status = .idle
            }
        case .ended:
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
