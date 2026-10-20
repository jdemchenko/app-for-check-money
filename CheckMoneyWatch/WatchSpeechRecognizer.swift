import AVFoundation
import Foundation
import Speech

/// Hold-to-talk speech for Watch — same SFSpeech path as iPhone, without phone L10n.
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
    @Published private(set) var isAuthorized = false

    var onUtteranceFinished: ((String) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var releaseTailTask: Task<Void, Never>?
    private var didEmitFinished = false
    private var tapInstalled = false
    private var lastPartial = ""
    private var finalText: String?

    private let releaseTailNanoseconds: UInt64 = 450_000_000

    var isListening: Bool { status == .listening }

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    init() {
        let speechLocale = isRussian
            ? Locale(identifier: "ru-RU")
            : Locale(identifier: "en-US")
        recognizer = SFSpeechRecognizer(locale: speechLocale)
        if recognizer == nil {
            status = .unavailable(isRussian ? "Речь недоступна" : "Speech unavailable")
        }
    }

    func prepare() async {
        guard recognizer != nil else {
            status = .unavailable(isRussian ? "Речь недоступна" : "Speech unavailable")
            return
        }
        status = .requestingPermission
        let speechOk = await requestSpeechAuth()
        let micOk = await requestMicAuth()
        isAuthorized = speechOk && micOk
        if !isAuthorized {
            status = .unavailable(isRussian ? "Нет доступа к микрофону" : "Mic permission denied")
        } else {
            status = .idle
        }
    }

    func start() {
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable(isRussian ? "Речь недоступна" : "Speech unavailable")
            return
        }
        guard isAuthorized else {
            Task {
                await prepare()
                if isAuthorized { start() }
            }
            return
        }

        cancelReleaseTail()
        teardownEngine()
        task?.cancel()
        task = nil
        request = nil
        transcript = ""
        lastPartial = ""
        finalText = nil
        didEmitFinished = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch {
            status = .failed(error.localizedDescription)
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
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            status = .failed(isRussian ? "Нет микрофона" : "No microphone")
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
            teardownEngine()
            status = .failed(error.localizedDescription)
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
                        if !text.isEmpty { self.transcript = text }
                        self.emitFinishedAndCleanup()
                    } else {
                        self.lastPartial = text
                        self.transcript = text
                    }
                }
                if let error {
                    let ns = error as NSError
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
                    self.cancelReleaseTail()
                    self.teardownEngine()
                }
            }
        }
    }

    func stop() {
        beginGracefulStop()
    }

    private func beginGracefulStop() {
        guard !didEmitFinished else { return }
        if releaseTailTask != nil { return }

        request?.endAudio()
        if let engine = audioEngine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            if engine.isRunning { engine.stop() }
        }

        releaseTailTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: releaseTailNanoseconds)
            guard !Task.isCancelled else { return }
            emitFinishedAndCleanup()
        }
    }

    private func emitFinishedAndCleanup() {
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
        teardownEngine()

        if case .failed = status {
            // keep failed
        } else {
            status = .idle
        }

        guard !didEmitFinished else { return }
        didEmitFinished = true
        onUtteranceFinished?(text)
    }

    private func cancelReleaseTail() {
        releaseTailTask?.cancel()
        releaseTailTask = nil
    }

    private func teardownEngine() {
        if let engine = audioEngine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            if engine.isRunning { engine.stop() }
        }
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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
