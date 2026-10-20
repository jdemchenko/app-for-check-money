import SwiftUI

struct SettingsView: View {
    @ObservedObject private var currencySettings = CurrencySettings.shared
    @ObservedObject private var rates = ExchangeRateStore.shared
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

                    ratesBlock
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
            .task {
                rates.refreshIfNeeded()
            }
        }
    }

    private var ratesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuietSectionLabel(text: L10n.string("settings.ratesTitle"))

            GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rateLine(code: .usd))
                            Text(rateLine(code: .eur))
                            Text(rateLine(code: .rub))
                        }
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Button {
                            Task { await rates.refresh(force: true) }
                        } label: {
                            if rates.isRefreshing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.string("settings.ratesRefresh"))
                    }

                    Text(rates.ratesFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func rateLine(code: AppCurrency) -> String {
        let value = rates.bynPerUnit[code] ?? ExchangeRateStore.staticBynPerUnit[code] ?? 0
        let formatted = String(format: "%.4g", value)
        return "1 \(code.code) = \(formatted) BYN"
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
