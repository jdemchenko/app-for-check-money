import SwiftUI

/// Quiet CheckMoney cold-launch morph: brand + Liquid Glass → Home.
/// No stats, no purple glow — single accent wash only.
struct LaunchWowOverlay: View {
    var mode: LaunchWowStore.Phase
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var brandOpacity: Double = 0
    @State private var glassScale: CGFloat = 0.72
    @State private var glassBlur: CGFloat = 12
    @State private var morphProgress: CGFloat = 0
    @State private var overlayOpacity: Double = 1

    var body: some View {
        ZStack {
            AtmosphereBackground()

            glassMark
                .scaleEffect(glassScale)
                .blur(radius: glassBlur)
                .opacity(0.95)

            Text(L10n.string("app.name"))
                .font(.system(size: mode == .cold ? 36 : 28, weight: .semibold, design: .default))
                .tracking(0.6)
                .foregroundStyle(.primary)
                .opacity(brandOpacity)
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
        let corner = 28 + (1 - morphProgress) * 36
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let size: CGFloat = mode == .cold ? 168 : 96

        if #available(iOS 26.0, *), !reduceTransparency {
            Color.clear
                .frame(width: size, height: size)
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.fill(AppTheme.accent.opacity(scheme == .dark ? 0.10 : 0.06))
                }
                .overlay {
                    shape.strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay {
                    shape.fill(AppTheme.accent.opacity(scheme == .dark ? 0.10 : 0.06))
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

        // Cold: ~1.5s spring morph → fade to Home.
        brandOpacity = 0
        glassScale = 0.72
        glassBlur = 14
        morphProgress = 0
        overlayOpacity = 1

        withAnimation(.spring(response: 0.72, dampingFraction: 1.0)) {
            brandOpacity = 1
            glassScale = 1
            glassBlur = 0
            morphProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 0.42)) {
                overlayOpacity = 0
                glassScale = 1.12
                brandOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
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
