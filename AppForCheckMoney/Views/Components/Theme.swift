import SwiftUI

// MARK: - Design tokens (iOS continuous corner language)

enum AppTheme {
    /// Controls, chips, text fields, selectable cells — iOS continuous control feel.
    static let radiusControl: CGFloat = 14
    /// Cards, list containers, glass panels — system grouped-surface scale.
    static let radiusPanel: CGFloat = 22

    /// Back-compat aliases used by older call sites (all map into the two-token set).
    static let cornerSmall: CGFloat = radiusControl
    static let cornerMedium: CGFloat = radiusPanel
    static let cornerLarge: CGFloat = radiusPanel

    static let spaceSection: CGFloat = 24
    static let spaceItem: CGFloat = 12
    static let touchMin: CGFloat = 44

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
                Color.white.opacity(0.42),
                Color.white.opacity(0.06),
                Color.primary.opacity(0.05),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Shared continuous rounded rect for any interactive / surface chrome.
    static func continuousRect(_ radius: CGFloat = radiusControl) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
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
            // System-adjacent canvas (light: cool gray; dark: true black) — not cream/terracotta.
            (scheme == .dark ? Color.black : Color(hex: "F2F2F7"))
            RadialGradient(
                colors: [
                    Color(hex: "8E8E93").opacity(scheme == .dark ? 0.14 : 0.12),
                    .clear,
                ],
                center: UnitPoint(x: 0.12, y: -0.02),
                startRadius: 8,
                endRadius: 360
            )
            RadialGradient(
                colors: [
                    Color(hex: "636366").opacity(scheme == .dark ? 0.10 : 0.06),
                    .clear,
                ],
                center: UnitPoint(x: 0.92, y: 0.28),
                startRadius: 16,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 18
    /// Always `radiusPanel` — callers may pass legacy corner args; ignored for uniformity.
    var corner: CGFloat = AppTheme.radiusPanel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AppTheme.continuousRect(AppTheme.radiusPanel)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusPanel)
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
                AppTheme.continuousRect(AppTheme.radiusControl)
                    .fill(.thinMaterial)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusControl)
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

    /// Selectable chip / category cell chrome — always `radiusControl`.
    func glassChip(selected: Bool) -> some View {
        background {
            AppTheme.continuousRect(AppTheme.radiusControl)
                .fill(.thinMaterial)
                .overlay {
                    AppTheme.continuousRect(AppTheme.radiusControl)
                        .strokeBorder(
                            selected
                                ? Color.primary.opacity(0.32)
                                : Color.primary.opacity(0.08),
                            lineWidth: selected ? 1.0 : 0.5
                        )
                        .overlay {
                            AppTheme.continuousRect(AppTheme.radiusControl)
                                .fill(selected ? Color.primary.opacity(0.06) : Color.clear)
                        }
                }
        }
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
            .frame(minHeight: AppTheme.touchMin - 8)
            .padding(.vertical, 12)
            .foregroundStyle(isDestructive ? AppTheme.expense : Color.primary)
            .background {
                // Primary CTA uses the same continuous panel radius (not a freeform capsule mix).
                AppTheme.continuousRect(AppTheme.radiusPanel)
                    .fill(.thinMaterial)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusPanel)
                            .strokeBorder(
                                (isDestructive ? AppTheme.expense : Color.primary).opacity(0.16),
                                lineWidth: 0.7
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
            // Glyph wells stay circular (symbol container), not a third radius token.
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
