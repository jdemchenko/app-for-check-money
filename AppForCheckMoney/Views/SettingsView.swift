import SwiftUI

struct SettingsView: View {
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    QuietSectionLabel(text: L10n.string("settings.currency"))

                    GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                        VStack(spacing: 0) {
                            ForEach(AppCurrency.allCases) { code in
                                Button {
                                    currencySettings.currency = code
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
                                        if currencySettings.currency == code {
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

                    Text(L10n.string("settings.currencyHint"))
                        .font(.footnote)
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
}
