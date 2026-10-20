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

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    var isAvailable: Bool {
        let auth = SFSpeechRecognizer.authorizationStatus()
        guard auth != .denied, auth != .restricted else { return false }
        return recognizer?.isAvailable == true
    }

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
            Task { await prepare(); if isAuthorized { start() } }
            return
        }

        stop()
        transcript = ""

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
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
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stop()
                    }
                }
                if let error {
                    // Cancellation is expected when stopping.
                    let ns = error as NSError
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 216 {
                        return
                    }
                    if self.status == .listening {
                        self.status = .failed(error.localizedDescription)
                    }
                    self.stopEngineOnly()
                }
            }
        }
    }

    func stop() {
        request?.endAudio()
        stopEngineOnly()
        task?.cancel()
        task = nil
        request = nil
        if status == .listening {
            status = .idle
        }
    }

    func clearTranscript() {
        transcript = ""
    }

    private func stopEngineOnly() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
