import SwiftUI

// MARK: - Design tokens (HIG / quiet Liquid Glass)

enum AppTheme {
    /// Controls, chips, text fields — continuous iOS control radius.
    static let radiusControl: CGFloat = 12
    /// Panels / sheets — soft continuous surface (not pill-y).
    static let radiusPanel: CGFloat = 20

    static let cornerSmall: CGFloat = radiusControl
    static let cornerMedium: CGFloat = radiusPanel
    static let cornerLarge: CGFloat = radiusPanel

    /// Ample vertical rhythm between major sections.
    static let spaceSection: CGFloat = 32
    static let spaceItem: CGFloat = 14
    static let spaceTight: CGFloat = 8
    static let touchMin: CGFloat = 44
    /// Horizontal page inset.
    static let pageInset: CGFloat = 22

    /// Single accent — muted slate-teal (not purple, not neon).
    static let accent = Color(hex: "3A6B6E")
    /// Functional cues only — low chroma.
    static let income = Color(hex: "2A6B45")
    static let expense = Color(hex: "B03A35")
    static let positive = income
    static let negative = expense

    /// Crisp 1px border language.
    static let borderWidth: CGFloat = 1.0

    /// Quiet spring for press / listen / sheet content.
    static var springSnappy: Animation {
        .spring(response: 0.32, dampingFraction: 0.78)
    }
    static var springSoft: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
    }

    // MARK: Scheme-aware surfaces

    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "000000") : Color(hex: "F2F2F7")
    }

    static func elevatedFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1C1C1E").opacity(0.78) : Color.white.opacity(0.92)
    }

    static func labelSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.secondary : Color(hex: "3A3A3C")
    }

    static func labelTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.secondary.opacity(0.82) : Color(hex: "636366")
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)
    }

    static func selectionStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? AppTheme.accent.opacity(0.55) : AppTheme.accent.opacity(0.70)
    }

    static func trackFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func trackValue(_ scheme: ColorScheme, emphasized: Bool = false) -> Color {
        if emphasized { return AppTheme.expense.opacity(scheme == .dark ? 0.75 : 0.85) }
        return AppTheme.accent.opacity(scheme == .dark ? 0.55 : 0.65)
    }

    /// Subtle rim — no heavy multi-stop glow.
    static func glassStroke(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.90), Color.black.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
            // One soft wash — depth without muddy clutter.
            RadialGradient(
                colors: [
                    AppTheme.accent.opacity(scheme == .dark ? 0.10 : 0.05),
                    .clear,
                ],
                center: UnitPoint(x: 0.15, y: -0.05),
                startRadius: 4,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces (iOS 26 Liquid Glass + dual-path)

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 20
    var corner: CGFloat = AppTheme.radiusPanel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder var content: Content

    var body: some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusPanel)
        let padded = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)

        if #available(iOS 26.0, *), !reduceTransparency {
            padded
                .glassEffect(.regular, in: shape)
        } else {
            padded
                .background {
                    shape
                        .fill(panelFill)
                        .overlay {
                            shape.strokeBorder(
                                AppTheme.hairline(scheme),
                                lineWidth: AppTheme.borderWidth
                            )
                        }
                        // No heavy drop shadow — hairline only.
                }
        }
    }

    private var panelFill: AnyShapeStyle {
        if scheme == .dark {
            AnyShapeStyle(.ultraThinMaterial)
        } else {
            AnyShapeStyle(AppTheme.elevatedFill(scheme))
        }
    }
}

struct GlassFieldBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusControl)
        let field = content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

        if #available(iOS 26.0, *), !reduceTransparency {
            field.glassEffect(.regular, in: shape)
        } else {
            field.background {
                shape
                    .fill(scheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white))
                    .overlay {
                        shape.strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                    }
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

    func glassChip(selected: Bool) -> some View {
        modifier(GlassChipBackground(selected: selected))
    }

    func quietInteractiveGlassCircle(listening: Bool = false) -> some View {
        modifier(QuietInteractiveGlassCircle(listening: listening))
    }

    func quietGlassSurface(corner: CGFloat, interactive: Bool = false) -> some View {
        modifier(QuietGlassSurface(corner: corner, interactive: interactive))
    }
}

private struct QuietInteractiveGlassCircle: ViewModifier {
    var listening: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .frame(width: 112, height: 112)
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay {
                    Circle()
                        .fill(AppTheme.accent.opacity(listening ? 0.14 : 0.04))
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            listening
                                ? AppTheme.accent.opacity(0.45)
                                : AppTheme.hairline(scheme),
                            lineWidth: AppTheme.borderWidth
                        )
                }
        } else {
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 112, height: 112)
                        .overlay {
                            Circle()
                                .fill(AppTheme.accent.opacity(listening ? 0.14 : 0.05))
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    listening
                                        ? AppTheme.accent.opacity(0.40)
                                        : AppTheme.hairline(scheme),
                                    lineWidth: AppTheme.borderWidth
                                )
                        }
                }
                .frame(width: 112, height: 112)
        }
    }
}

private struct QuietGlassSurface: ViewModifier {
    var corner: CGFloat
    var interactive: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(corner)
        if #available(iOS 26.0, *), !reduceTransparency {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
                    }
            }
        }
    }
}

private struct GlassChipBackground: ViewModifier {
    var selected: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusControl)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(
                    selected ? .regular.interactive() : .regular,
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        selected ? AppTheme.selectionStroke(scheme) : Color.clear,
                        lineWidth: selected ? AppTheme.borderWidth : 0
                    )
                }
        } else {
            content
                .background {
                    shape
                        .fill(chipFill)
                        .overlay {
                            shape.strokeBorder(
                                selected
                                    ? AppTheme.selectionStroke(scheme)
                                    : AppTheme.hairline(scheme),
                                lineWidth: AppTheme.borderWidth
                            )
                        }
                        .overlay {
                            shape.fill(
                                selected
                                    ? AppTheme.accent.opacity(scheme == .dark ? 0.12 : 0.08)
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
            AnyShapeStyle(Color.white.opacity(selected ? 1 : 0.90))
        }
    }
}

struct GlassActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
            .modifier(GlassActionChrome(
                isDestructive: isDestructive,
                scheme: scheme,
                reduceTransparency: reduceTransparency
            ))
        }
        .buttonStyle(.plain)
    }
}

private struct GlassActionChrome: ViewModifier {
    var isDestructive: Bool
    var scheme: ColorScheme
    var reduceTransparency: Bool

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusPanel)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background {
                shape
                    .fill(scheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white))
                    .overlay {
                        shape.strokeBorder(
                            (isDestructive ? AppTheme.expense : AppTheme.accent)
                                .opacity(scheme == .dark ? 0.35 : 0.28),
                            lineWidth: AppTheme.borderWidth
                        )
                    }
            }
        }
    }
}

struct CategoryGlyph: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 40
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
                .overlay {
                    Circle().fill(AppTheme.accent.opacity(scheme == .dark ? 0.12 : 0.10))
                }
                .overlay {
                    Circle().strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
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
            .tracking(0.2)
    }
}

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
                AppTheme.continuousRect(AppTheme.radiusControl)
                    .strokeBorder(AppTheme.hairline(scheme), lineWidth: AppTheme.borderWidth)
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
