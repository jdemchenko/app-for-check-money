import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var currencySettings = CurrencySettings.shared

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .opacity(0.92)
            Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: AppTheme.spaceSection) {
                VStack(alignment: .leading, spacing: AppTheme.spaceTight) {
                    Text(L10n.string("app.name"))
                        .font(AppTheme.TypeScale.largeTitle)
                        .foregroundStyle(.primary)

                    Text(L10n.string("onboarding.headline"))
                        .font(AppTheme.TypeScale.title3.weight(.medium))
                        .themeSecondary()
                }

                VStack(alignment: .leading, spacing: AppTheme.spaceItem) {
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

                VStack(alignment: .leading, spacing: AppTheme.spaceTight) {
                    QuietSectionLabel(text: L10n.string("settings.entryCurrency"))
                    Picker(L10n.string("settings.entryCurrency"), selection: $currencySettings.entryCurrency) {
                        ForEach(AppCurrency.allCases) { code in
                            Text(code.code).tag(code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onAppear {
                        if !UserDefaults.standard.bool(forKey: "settings.onboarding.currencyTouched") {
                            currencySettings.entryCurrency = .byn
                            currencySettings.displayCurrency = .byn
                        }
                    }
                    .onChange(of: currencySettings.entryCurrency) { _, _ in
                        UserDefaults.standard.set(true, forKey: "settings.onboarding.currencyTouched")
                    }
                }

                GlassActionButton(title: L10n.string("onboarding.continue")) {
                    onFinish()
                }
            }
            .padding(28)
            .frame(maxWidth: 400)
            .background {
                AppTheme.continuousRect(AppTheme.radiusPanel)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusPanel)
                            .strokeBorder(AppTheme.hairline(colorScheme), lineWidth: AppTheme.borderWidth)
                    }
            }
            .padding(AppTheme.pageInset)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private func tipRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.TypeScale.subheadline.weight(.semibold))
                Text(body)
                    .font(AppTheme.TypeScale.footnote)
                    .themeTertiary()
            }
        }
    }
}
