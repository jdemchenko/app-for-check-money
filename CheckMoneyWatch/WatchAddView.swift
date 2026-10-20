import SwiftUI

/// Quick expense on Watch: amount + category.
/// Dictation: system keyboard mic on amount/note fields (watchOS Speech freestyle is limited).
struct WatchAddView: View {
    @EnvironmentObject private var store: WatchStore

    @State private var amountText = ""
    @State private var note = ""
    @State private var categoryId: String = "food"
    @State private var currency: SharedCurrencyCode = .byn
    @State private var savedFlash = false

    private var isRussian: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("ru") == true
    }

    private var categories: [SharedCategoryDTO] {
        let cats = store.snapshot.categories.filter { $0.kindRaw != "income" }
        return cats.isEmpty ? SharedSeed.defaultExpenseCategories : cats
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isRussian ? "Сумма" : "Amount", text: $amountText)
                        .font(.title3.monospacedDigit())
                    #if os(watchOS)
                        .textInputAutocapitalization(.never)
                    #endif

                    Picker(isRussian ? "Валюта" : "Currency", selection: $currency) {
                        ForEach(SharedCurrencyCode.allCases) { code in
                            Text(code.code).tag(code)
                        }
                    }

                    Picker(isRussian ? "Категория" : "Category", selection: $categoryId) {
                        ForEach(categories) { cat in
                            Label(cat.displayName(isRussian: isRussian), systemImage: cat.symbolName)
                                .tag(cat.id)
                        }
                    }

                    TextField(isRussian ? "Заметка (диктовка)" : "Note (dictation)", text: $note)
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Label(
                            savedFlash
                                ? (isRussian ? "Записано" : "Saved")
                                : (isRussian ? "Сохранить" : "Save"),
                            systemImage: savedFlash ? "checkmark" : "plus.circle.fill"
                        )
                    }
                    .disabled(parsedAmount == nil)
                }

                Section {
                    Text(
                        isRussian
                            ? "Диктовка — через микрофон клавиатуры. Полный голос как на iPhone на Watch ограничен."
                            : "Use the keyboard mic for dictation. Full free-form speech like iPhone is limited on watchOS."
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle(isRussian ? "Добавить" : "Add")
            .onAppear {
                if let first = categories.first {
                    categoryId = first.id
                }
                if let code = SharedCurrencyCode(rawValue: store.snapshot.displayCurrencyRaw) {
                    currency = code
                }
            }
        }
    }

    private var parsedAmount: Double? {
        let cleaned = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return (value * 100).rounded() / 100
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addExpense(
            amount: amount,
            categoryId: categoryId,
            note: trimmed.isEmpty ? nil : trimmed,
            currency: currency
        )
        amountText = ""
        note = ""
        savedFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            savedFlash = false
        }
    }
}
