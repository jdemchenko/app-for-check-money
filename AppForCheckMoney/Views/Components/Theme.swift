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
    static let accent = Color(hex: "1C1C1E")
    /// Functional, low-chroma cues (Wallet/Revolut-adjacent; not candy).
    static let income = Color(hex: "1F7A36")
    static let expense = Color(hex: "C0322A")
    static let positive = income
    static let negative = expense

    // MARK: Scheme-aware readability (light focus)

    /// Grouped canvas — system Settings gray in light; true black in dark.
    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : Color(hex: "F2F2F7")
    }

    /// Elevated surface (panels) — near-white in light for contrast vs canvas.
    static func elevatedFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1C1C1E").opacity(0.72) : Color.white.opacity(0.94)
    }

    /// Section / secondary labels — stronger than system `.secondary` on glass (light).
    static func labelSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.secondary : Color(hex: "3A3A3C")
    }

    /// Tertiary / captions — still quieter, but not muddy gray-on-gray in light.
    static func labelTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.secondary.opacity(0.85) : Color(hex: "636366")
    }

    /// Hairline separators and field rings.
    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    /// Selected chip / control ring.
    static func selectionStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.36) : Color.black.opacity(0.28)
    }

    /// Track fills (budget / category bars).
    static func trackFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.10) : Color.black.opacity(0.07)
    }

    static func trackValue(_ scheme: ColorScheme, emphasized: Bool = false) -> Color {
        if scheme == .dark {
            return Color.primary.opacity(emphasized ? 0.50 : 0.32)
        }
        return Color.black.opacity(emphasized ? 0.42 : 0.28)
    }

    static func glassStroke(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.36),
                    Color.white.opacity(0.08),
                    Color.primary.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        // Light: darker rim so panels read on F2F2F7 (Wallet-style clarity).
        return LinearGradient(
            colors: [
                Color.white.opacity(0.95),
                Color.black.opacity(0.06),
                Color.black.opacity(0.10),
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
            AppTheme.canvas(scheme)
            // Quiet depth only — avoid muddy gray washes that flatten body text.
            RadialGradient(
                colors: [
                    Color(hex: scheme == .dark ? "8E8E93" : "AEAEB2")
                        .opacity(scheme == .dark ? 0.14 : 0.07),
                    .clear,
                ],
                center: UnitPoint(x: 0.12, y: -0.02),
                startRadius: 8,
                endRadius: 340
            )
            RadialGradient(
                colors: [
                    Color(hex: scheme == .dark ? "636366" : "C7C7CC")
                        .opacity(scheme == .dark ? 0.10 : 0.05),
                    .clear,
                ],
                center: UnitPoint(x: 0.92, y: 0.28),
                startRadius: 16,
                endRadius: 280
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
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                AppTheme.continuousRect(AppTheme.radiusPanel)
                    .fill(panelFill)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusPanel)
                            .strokeBorder(AppTheme.glassStroke(scheme), lineWidth: scheme == .dark ? 0.6 : 0.8)
                    }
                    .shadow(
                        color: .black.opacity(scheme == .dark ? 0.28 : 0.07),
                        radius: scheme == .dark ? 16 : 12,
                        y: scheme == .dark ? 6 : 4
                    )
            }
    }

    private var panelFill: AnyShapeStyle {
        if scheme == .dark {
            AnyShapeStyle(.ultraThinMaterial)
        } else {
            // Light: opaque-enough white so labels aren’t gray-on-gray through material.
            AnyShapeStyle(AppTheme.elevatedFill(scheme))
        }
    }
}

struct GlassFieldBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                AppTheme.continuousRect(AppTheme.radiusControl)
                    .fill(scheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white))
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusControl)
                            .strokeBorder(AppTheme.hairline(scheme), lineWidth: 0.7)
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
        modifier(GlassChipBackground(selected: selected))
    }
}

private struct GlassChipBackground: ViewModifier {
    var selected: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                AppTheme.continuousRect(AppTheme.radiusControl)
                    .fill(chipFill)
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusControl)
                            .strokeBorder(
                                selected
                                    ? AppTheme.selectionStroke(scheme)
                                    : AppTheme.hairline(scheme),
                                lineWidth: selected ? 1.1 : 0.7
                            )
                            .overlay {
                                AppTheme.continuousRect(AppTheme.radiusControl)
                                    .fill(
                                        selected
                                            ? (scheme == .dark
                                                ? Color.primary.opacity(0.08)
                                                : Color.black.opacity(0.04))
                                            : Color.clear
                                    )
                            }
                    }
            }
    }

    private var chipFill: AnyShapeStyle {
        if scheme == .dark {
            AnyShapeStyle(.thinMaterial)
        } else {
            AnyShapeStyle(Color.white.opacity(selected ? 1 : 0.88))
        }
    }
}

struct GlassActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

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
                AppTheme.continuousRect(AppTheme.radiusPanel)
                    .fill(scheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white))
                    .overlay {
                        AppTheme.continuousRect(AppTheme.radiusPanel)
                            .strokeBorder(
                                (isDestructive ? AppTheme.expense : Color.primary)
                                    .opacity(scheme == .dark ? 0.18 : 0.14),
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = Color(hex: colorHex)
        ZStack {
            Circle()
                .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                .overlay {
                    Circle().fill(tint.opacity(scheme == .dark ? 0.14 : 0.16))
                }
                .overlay {
                    Circle().strokeBorder(
                        scheme == .dark ? Color.white.opacity(0.28) : AppTheme.hairline(scheme),
                        lineWidth: 0.7
                    )
                }
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(scheme == .dark ? 0.88 : 0.92))
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct QuietSectionLabel: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.labelSecondary(scheme))
            .textCase(nil)
    }
}

/// Inset list row chrome — white in light (readable), material in dark.
struct ListRowGlassBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        AppTheme.continuousRect(AppTheme.radiusControl)
            .fill(
                scheme == .dark
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AnyShapeStyle(Color.white.opacity(0.94))
            )
            .overlay {
                if scheme != .dark {
                    AppTheme.continuousRect(AppTheme.radiusControl)
                        .strokeBorder(AppTheme.hairline(scheme), lineWidth: 0.5)
                }
            }
            .padding(.vertical, 2)
    }
}

extension View {
    func themeSecondary() -> some View {
        modifier(ThemeSecondaryForeground())
    }

    func themeTertiary() -> some View {
        modifier(ThemeTertiaryForeground())
    }
}

private struct ThemeSecondaryForeground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.foregroundStyle(AppTheme.labelSecondary(scheme))
    }
}

private struct ThemeTertiaryForeground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.foregroundStyle(AppTheme.labelTertiary(scheme))
    }
}
