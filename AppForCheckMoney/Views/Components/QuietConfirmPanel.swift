import SwiftUI

/// Compact glass confirm — quiet HIG surface, no bulky system action sheet.
struct QuietConfirmPanel: View {
    let title: String
    var message: String? = nil
    let confirmTitle: String
    var confirmDestructive: Bool = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceItem) {
            Text(title)
                .font(.headline.weight(.semibold))
            if let message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .themeSecondary()
                    .fixedLineLimit()
            }
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text(L10n.string("common.cancel"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppTheme.touchMin)
                        .padding(.horizontal, 8)
                        .modifier(QuietConfirmButtonChrome(emphasized: false, destructive: false))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(confirmDestructive ? AppTheme.expense : AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppTheme.touchMin)
                        .padding(.horizontal, 8)
                        .modifier(
                            QuietConfirmButtonChrome(
                                emphasized: true,
                                destructive: confirmDestructive
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .modifier(QuietConfirmPanelChrome(scheme: colorScheme, reduceTransparency: reduceTransparency))
        .padding(.horizontal, AppTheme.pageInset + 6)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .animation(AppTheme.springSoft, value: title)
    }
}

private extension View {
    /// Multi-line confirm body without truncating batch lists.
    func fixedLineLimit() -> some View {
        self.lineLimit(12)
            .multilineTextAlignment(.leading)
    }
}

private struct QuietConfirmButtonChrome: ViewModifier {
    var emphasized: Bool
    var destructive: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusControl)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(
                emphasized ? .regular.interactive() : .regular,
                in: shape
            )
            .overlay {
                if emphasized {
                    shape.strokeBorder(
                        (destructive ? AppTheme.expense : AppTheme.accent).opacity(0.35),
                        lineWidth: AppTheme.borderWidth
                    )
                }
            }
        } else {
            content.background {
                shape
                    .fill(emphasized ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay {
                        shape.strokeBorder(
                            emphasized
                                ? (destructive ? AppTheme.expense : AppTheme.accent).opacity(0.32)
                                : AppTheme.hairline(scheme),
                            lineWidth: AppTheme.borderWidth
                        )
                    }
            }
        }
    }
}

private struct QuietConfirmPanelChrome: ViewModifier {
    var scheme: ColorScheme
    var reduceTransparency: Bool

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusPanel)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: shape)
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
