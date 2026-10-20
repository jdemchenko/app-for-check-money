import SwiftUI

// MARK: - Tokens (restrained — Apple Design Awards / HIG quiet chrome)

enum AppTheme {
    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 18
    static let cornerSmall: CGFloat = 12
    static let spaceSection: CGFloat = 24
    static let spaceItem: CGFloat = 12
    /// Restrained ink — avoid saturated brand washes.
    static let accent = Color.primary
    static let income = Color.primary
    static let expense = Color.secondary
    static let positive = Color.primary
    static let negative = Color.secondary

    static var glassStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.35),
                Color.white.opacity(0.06),
                Color.primary.opacity(0.05),
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
            (a, r, g, b) = (255, 58, 58, 60)
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

/// Soft neutral field — no rainbow washes.
struct AtmosphereBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color(hex: "F2F2F7"))
            RadialGradient(
                colors: [
                    Color.primary.opacity(scheme == .dark ? 0.08 : 0.04),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
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
                            .strokeBorder(AppTheme.glassStroke, lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
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
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
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
            .padding(.vertical, 14)
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
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
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
                }
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.primary)
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
