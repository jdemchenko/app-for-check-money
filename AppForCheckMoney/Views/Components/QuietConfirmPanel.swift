import SwiftUI

/// Compact glass confirm — avoids bulky system white action sheets.
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
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text(L10n.string("common.cancel"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 8)
                        .modifier(QuietConfirmButtonChrome(emphasized: false, destructive: false))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(confirmDestructive ? AppTheme.expense : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
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
        .padding(18)
        .modifier(QuietConfirmPanelChrome(scheme: colorScheme, reduceTransparency: reduceTransparency))
        .padding(.horizontal, 28)
    }
}

private struct QuietConfirmButtonChrome: ViewModifier {
    var emphasized: Bool
    var destructive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.radiusControl)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(
                emphasized ? .regular.interactive() : .regular,
                in: shape
            )
        } else {
            content.background {
                shape
                    .fill(emphasized ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay {
                        if emphasized {
                            shape.strokeBorder(
                                (destructive ? AppTheme.expense : Color.primary).opacity(0.18),
                                lineWidth: 0.7
                            )
                        }
                    }
            }
        }
    }
}

private struct QuietConfirmPanelChrome: ViewModifier {
    var scheme: ColorScheme
    var reduceTransparency: Bool

    func body(content: Content) -> some View {
        let shape = AppTheme.continuousRect(AppTheme.cornerLarge)
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.strokeBorder(AppTheme.glassStroke(scheme), lineWidth: 1)
                    }
            }
        }
    }
}
