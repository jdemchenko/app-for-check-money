import SwiftUI

// MARK: - Tokens

enum AppTheme {
    static let cornerLarge: CGFloat = 28
    static let cornerMedium: CGFloat = 20
    static let cornerSmall: CGFloat = 14
    static let spaceSection: CGFloat = 28
    static let spaceItem: CGFloat = 12
    static let accent = Color(hex: "0A84FF")
    static let income = Color(hex: "34C759")
    static let expense = Color(hex: "FF3B30")

    /// Soft specular rim — reads as glass edge light in both appearances.
    static var glassStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.08),
                Color.primary.opacity(0.06),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (a, r, g, b) = (255, 10, 132, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Atmosphere

/// Soft depth field behind content — adapts to light/dark, no flat gray chrome.
struct AtmosphereBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color(hex: "EEF3F8"))
            RadialGradient(
                colors: [
                    AppTheme.accent.opacity(scheme == .dark ? 0.28 : 0.18),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Color(hex: "64D2FF").opacity(scheme == .dark ? 0.14 : 0.12),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 360
            )
            RadialGradient(
                colors: [
                    AppTheme.income.opacity(scheme == .dark ? 0.08 : 0.06),
                    .clear,
                ],
                center: .bottom,
                startRadius: 40,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces

/// Frosted liquid-glass panel (ultra-thin material + specular rim + soft depth).
struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 18
    var corner: CGFloat = AppTheme.cornerLarge
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(AppTheme.glassStroke, lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
            }
    }
}

/// Quieter inset field on glass.
struct GlassFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func glassField() -> some View {
        modifier(GlassFieldBackground())
    }

    /// Screen chrome: atmosphere + hide heavy grouped gray.
    func liquidScreen() -> some View {
        background { AtmosphereBackground() }
            .scrollContentBackground(.hidden)
    }
}

/// Primary liquid action — glass capsule with accent wash.
struct GlassActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background {
                Capsule(style: .continuous)
                    .fill(isDestructive ? AppTheme.expense : AppTheme.accent)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    }
                    .shadow(
                        color: (isDestructive ? AppTheme.expense : AppTheme.accent).opacity(0.35),
                        radius: 16,
                        y: 8
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryGlyph: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 40

    var body: some View {
        let tint = Color(hex: colorHex)
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle().fill(tint.opacity(0.22))
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                }
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

/// Minimal section label — no heavy chrome.
struct QuietSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}
