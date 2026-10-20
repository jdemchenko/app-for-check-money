import SwiftUI

// MARK: - Tokens (ADA: gripping but restrained)

enum AppTheme {
    static let cornerLarge: CGFloat = 26
    static let cornerMedium: CGFloat = 18
    static let cornerSmall: CGFloat = 12
    static let spaceSection: CGFloat = 26
    static let spaceItem: CGFloat = 12

    /// Soft ink accent — readable without marketing neon.
    static let accent = Color(hex: "2C2C2E")
    /// Functional, low-chroma cues (not candy).
    static let income = Color(hex: "248A3D")
    static let expense = Color(hex: "C9342C")
    static let positive = income
    static let negative = expense

    static var glassStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.45),
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
            (a, r, g, b) = (255, 44, 44, 46)
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

struct AtmosphereBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(hex: "000000") : Color(hex: "F5F5F7"))
            RadialGradient(
                colors: [
                    Color(hex: "A8B4C4").opacity(scheme == .dark ? 0.16 : 0.22),
                    .clear,
                ],
                center: UnitPoint(x: 0.15, y: 0.0),
                startRadius: 10,
                endRadius: 380
            )
            RadialGradient(
                colors: [
                    Color(hex: "D4D0C8").opacity(scheme == .dark ? 0.08 : 0.18),
                    .clear,
                ],
                center: UnitPoint(x: 0.9, y: 0.25),
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces

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
                            .strokeBorder(AppTheme.glassStroke, lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
            }
    }
}

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
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func glassField() -> some View {
        modifier(GlassFieldBackground())
    }

    func liquidScreen() -> some View {
        background { AtmosphereBackground() }
            .scrollContentBackground(.hidden)
    }
}

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
            .foregroundStyle(isDestructive ? AppTheme.expense : Color.primary)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                (isDestructive ? AppTheme.expense : Color.primary).opacity(0.18),
                                lineWidth: 0.8
                            )
                    }
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
                    Circle().fill(tint.opacity(0.14))
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                }
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.85))
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct QuietSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}
