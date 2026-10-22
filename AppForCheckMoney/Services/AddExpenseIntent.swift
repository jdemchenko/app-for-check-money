import AppIntents
import SwiftData
import Foundation

/// Siri / Shortcuts: add an expense without opening the full UI (no paid team needed).
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add expense"
    static var description: IntentDescription {
        IntentDescription("Log a CheckMoney expense by amount and optional note.")
    }

    /// Keep Shortcuts/Siri able to run without bringing the UI forward.
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Note", default: "")
    var note: String

    @Parameter(title: "Spoken text", default: "")
    var spokenText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) expense") {
            \.$note
            \.$spokenText
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw AddExpenseIntentError.invalidAmount
        }

        let container = try DataStore.makeContainer()
        let context = ModelContext(container)
        SeedData.ensureDefaults(in: context)

        let categories = (try? context.fetch(FetchDescriptor<MoneyCategory>())) ?? []
        let entryCurrency = CurrencySettings.shared.entryCurrency

        var categoryId: String?
        var resolvedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var currency = entryCurrency
        var type: TransactionType = .expense

        let speech = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !speech.isEmpty {
            let draft = VoiceParser.parse(rawText: speech, categories: categories)
            categoryId = draft.categoryId
            if resolvedNote.isEmpty { resolvedNote = draft.note }
            if let c = draft.currency { currency = c }
            type = draft.type ?? .expense
        } else if !resolvedNote.isEmpty {
            let matched = CategoryMatcher.autoAssign(
                text: resolvedNote,
                categories: categories,
                preferredType: .expense
            )
            categoryId = matched?.id
        }

        if categoryId == nil {
            categoryId = CategoryMatcher.categories(for: .expense, in: categories).first?.id
                ?? categories.first?.id
        }
        guard let categoryId else {
            throw AddExpenseIntentError.noCategory
        }

        let tx = MoneyTransaction(
            amount: (amount * 100).rounded() / 100,
            type: type,
            categoryId: categoryId,
            note: resolvedNote.isEmpty ? nil : resolvedNote,
            date: .now,
            source: speech.isEmpty ? .manual : .voice,
            currency: currency
        )
        context.insert(tx)
        try context.save()

        let label = MoneyFormat.currency(tx.amount, code: currency)
        return .result(dialog: IntentDialog(stringLiteral: label))
    }
}

enum AddExpenseIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case noCategory

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount: return "Amount must be greater than zero"
        case .noCategory: return "No expense category available"
        }
    }
}

/// Log from free-form text (Shortcuts Share Sheet → this intent).
struct LogExpenseFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Log expense from text"
    static var description: IntentDescription {
        IntentDescription("Parse a phrase like “coffee 5” and save or open a draft.")
    }

    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        IncomingDraftStore.shared.offer(text)
        return .result()
    }
}

struct CheckMoneyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Добавь расход в \(.applicationName)",
            ],
            shortTitle: "Add expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: LogExpenseFromTextIntent(),
            phrases: [
                "Log spending in \(.applicationName)",
                "Запиши трату в \(.applicationName)",
            ],
            shortTitle: "Log from text",
            systemImageName: "text.badge.plus"
        )
    }
}
