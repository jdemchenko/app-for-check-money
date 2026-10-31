import SwiftUI

/// Elevated CheckMoney cold-launch morph: brand-first quiet Liquid Glass → Home.
/// Still no stats / purple glow. Reduce Motion → instant skip.
struct LaunchWowOverlay: View {
    var mode: LaunchWowStore.Phase
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var brandOpacity: Double = 0
    @State private var brandTracking: CGFloat = 4
    @State private var brandOffset: CGFloat = 12
    @State private var glassScale: CGFloat = 0.42
    @State private var glassBlur: CGFloat = 22
    @State private var morphProgress: CGFloat = 0
    @State private var glassOpacity: Double = 0.55
    @State private var washOpacity: Double = 0
    @State private var overlayOpacity: Double = 1

    var body: some View {
        ZStack {
            AtmosphereBackground()

            // Soft accent bloom behind the glass mark (quiet depth, not glow spam).
            Circle()
                .fill(AppTheme.accent.opacity(scheme == .dark ? 0.18 : 0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 48)
                .scaleEffect(0.7 + morphProgress * 0.55)
                .opacity(washOpacity)

            glassMark
                .scaleEffect(glassScale)
                .blur(radius: glassBlur)
                .opacity(glassOpacity)

            Text(L10n.string("app.name"))
                .font(AppTheme.TypeScale.largeTitle)
                .tracking(brandTracking)
                .foregroundStyle(.primary)
                .opacity(brandOpacity)
                .offset(y: brandOffset)
                .accessibilityAddTraits(.isHeader)
        }
        .opacity(overlayOpacity)
        .ignoresSafeArea()
        .allowsHitTesting(mode == .cold)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.string("app.name"))
        .onAppear { run() }
    }

    @ViewBuilder
    private var glassMark: some View {
        // Circle → continuous rounded square as morphProgress → 1.
        let corner = 84 - morphProgress * 64
        let shape = RoundedRectangle(cornerRadius: max(20, corner), style: .continuous)
        let size: CGFloat = 156 + morphProgress * 28

        if #available(iOS 26.0, *), !reduceTransparency {
            Color.clear
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay {
                    shape.fill(AppTheme.accent.opacity(scheme == .dark ? 0.12 : 0.07))
                }
                .overlay {
                    shape.strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay {
                    shape.fill(AppTheme.accent.opacity(scheme == .dark ? 0.12 : 0.07))
                }
                .overlay {
                    shape.strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                }
        }
    }

    private func run() {
        if reduceMotion || mode != .cold {
            onFinished()
            return
        }

        brandOpacity = 0
        brandTracking = 6
        brandOffset = 16
        glassScale = 0.38
        glassBlur = 24
        morphProgress = 0
        glassOpacity = 0.4
        washOpacity = 0
        overlayOpacity = 1

        // Phase 1 — glass blooms + brand settles (~0.9s critically damped).
        withAnimation(.spring(response: 0.85, dampingFraction: 1.0)) {
            brandOpacity = 1
            brandTracking = 0.4
            brandOffset = 0
            glassScale = 1
            glassBlur = 0
            morphProgress = 1
            glassOpacity = 1
            washOpacity = 1
        }

        // Phase 2 — expand through Home and dissolve.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.spring(response: 0.55, dampingFraction: 1.0)) {
                overlayOpacity = 0
                glassScale = 1.35
                washOpacity = 0
                brandOpacity = 0
                brandOffset = -8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            onFinished()
        }
    }
}

/// Environment flag so Home can run a one-shot balance / mic pulse.
private struct LaunchHomePulseKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var launchHomePulseToken: Int {
        get { self[LaunchHomePulseKey.self] }
        set { self[LaunchHomePulseKey.self] = newValue }
    }
}

/// Interpolates currency text for count-up hero reveals.
struct AnimatedCurrencyLabel: View, Animatable {
    var amount: Double
    var code: AppCurrency

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    var body: some View {
        Text(MoneyFormat.currency(amount, code: code))
    }
}
