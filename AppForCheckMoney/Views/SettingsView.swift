import SwiftUI

struct SettingsView: View {
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    currencyBlock(
                        title: L10n.string("settings.displayCurrency"),
                        subtitle: L10n.string("settings.displayCurrencyHint"),
                        selection: $currencySettings.displayCurrency
                    )

                    currencyBlock(
                        title: L10n.string("settings.entryCurrency"),
                        subtitle: L10n.string("settings.entryCurrencyHint"),
                        selection: $currencySettings.entryCurrency
                    )

                    Text(CurrencyConverter.ratesFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
        }
    }

    private func currencyBlock(
        title: String,
        subtitle: String,
        selection: Binding<AppCurrency>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: title)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.tertiary)

            GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                VStack(spacing: 0) {
                    ForEach(AppCurrency.allCases) { code in
                        Button {
                            selection.wrappedValue = code
                        } label: {
                            HStack(spacing: 12) {
                                Text(code.displaySymbol)
                                    .font(.body.weight(.semibold).monospaced())
                                    .frame(width: 36, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                Text(code.localizedTitle)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if selection.wrappedValue == code {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if code != AppCurrency.allCases.last {
                            Divider().opacity(0.2).padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }
}
