import SwiftUI

/// Primary Watch surface: hold to dictate one expense/income, parse, sync to iPhone.
struct WatchDictateView: View {
    @EnvironmentObject private var store: WatchStore
    @StateObject private var speech = WatchSpeechRecognizer()

    @State private var isHolding = false
    @State private var statusLine: String = ""
    @State private var flashSaved = false

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("CheckMoney")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 2)

            holdButton

            Spacer(minLength: 2)

            if !speech.transcript.isEmpty, isHolding || speech.isListening {
                Text(speech.transcript)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if flashSaved, let summary = store.lastSavedSummary {
                Text(summary)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else if let last = store.snapshot.recent.first {
                Text(lastLine(for: last))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if !store.isReachable {
                Text(isRussian ? "iPhone не рядом" : "iPhone away")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
        .task {
            speech.onUtteranceFinished = { text in
                handleFinished(text)
            }
            await speech.prepare()
        }
    }

    private var holdButton: some View {
        ZStack {
            Circle()
                .fill(isHolding ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.9))
                .frame(width: 88, height: 88)
                .scaleEffect(isHolding ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHolding)

            Image(systemName: isHolding ? "waveform" : "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: isHolding)
        }
        .accessibilityLabel(isRussian ? "Удерживайте и говорите" : "Hold to speak")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHolding else { return }
                    beginHold()
                }
                .onEnded { _ in
                    endHold()
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isHolding)
    }

    private func beginHold() {
        isHolding = true
        flashSaved = false
        statusLine = isRussian ? "Говорите…" : "Listening…"
        speech.start()
    }

    private func endHold() {
        guard isHolding else { return }
        isHolding = false
        statusLine = isRussian ? "Распознаю…" : "Parsing…"
        speech.stop()
    }

    private func handleFinished(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusLine = isRussian ? "Не расслышала — ещё раз" : "Didn’t catch that — retry"
            return
        }

        let cats = store.snapshot.categories.isEmpty
            ? SharedSeed.defaultExpenseCategories
            : store.snapshot.categories
        let draft = SharedVoiceParser.parse(rawText: trimmed, categories: cats)

        guard let amount = draft.amount, amount > 0 else {
            statusLine = isRussian ? "Нет суммы — повторите" : "No amount — try again"
            return
        }

        let defaultCurrency = store.snapshot.displayCurrency
        store.saveFromVoice(draft, defaultCurrency: defaultCurrency)
        flashSaved = true
        statusLine = ""
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            flashSaved = false
        }
    }

    private func lastLine(for tx: SharedTransactionDTO) -> String {
        let name = store.snapshot.categories.first { $0.id == tx.categoryId }?
            .displayName(isRussian: isRussian) ?? ""
        let sign = tx.isExpense ? "−" : "+"
        let money = SharedMoneyFormat.currency(tx.amount, code: tx.currency)
        if name.isEmpty { return "\(sign)\(money)" }
        return "\(name) \(sign)\(money)"
    }
}
