import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var currencySettings = CurrencySettings.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.string("app.name"))
                    .font(.largeTitle.weight(.bold))

                Text(L10n.string("onboarding.headline"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 14) {
                    tipRow(
                        symbol: "mic.fill",
                        title: L10n.string("onboarding.voiceTitle"),
                        body: L10n.string("onboarding.voiceBody")
                    )
                    tipRow(
                        symbol: "banknote",
                        title: L10n.string("onboarding.bynTitle"),
                        body: L10n.string("onboarding.bynBody")
                    )
                }

                QuietSectionLabel(text: L10n.string("settings.entryCurrency"))
                Picker(L10n.string("settings.entryCurrency"), selection: $currencySettings.entryCurrency) {
                    ForEach(AppCurrency.allCases) { code in
                        Text(code.code).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .onAppear {
                    // Default BYN for new installs.
                    if !UserDefaults.standard.bool(forKey: "settings.onboarding.currencyTouched") {
                        currencySettings.entryCurrency = .byn
                        currencySettings.displayCurrency = .byn
                    }
                }
                .onChange(of: currencySettings.entryCurrency) { _, _ in
                    UserDefaults.standard.set(true, forKey: "settings.onboarding.currencyTouched")
                }

                GlassActionButton(title: L10n.string("onboarding.continue")) {
                    onFinish()
                }
            }
            .padding(28)
            .frame(maxWidth: 400)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                            .strokeBorder(AppTheme.glassStroke, lineWidth: 1)
                    }
            }
            .padding(24)
        }
    }

    private func tipRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
