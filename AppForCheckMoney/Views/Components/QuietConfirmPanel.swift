import SwiftUI

/// Compact glass confirm — avoids bulky system white action sheets.
struct QuietConfirmPanel: View {
    let title: String
    var message: String? = nil
    let confirmTitle: String
    var confirmDestructive: Bool = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

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
                        .background {
                            AppTheme.continuousRect(AppTheme.radiusControl)
                                .fill(.ultraThinMaterial)
                        }
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(confirmDestructive ? AppTheme.expense : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background {
                            AppTheme.continuousRect(AppTheme.radiusControl)
                                .fill(.thinMaterial)
                                .overlay {
                                    AppTheme.continuousRect(AppTheme.radiusControl)
                                        .strokeBorder(
                                            (confirmDestructive ? AppTheme.expense : Color.primary).opacity(0.18),
                                            lineWidth: 0.7
                                        )
                                }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background {
            AppTheme.continuousRect(AppTheme.cornerLarge)
                .fill(.ultraThinMaterial)
                .overlay {
                    AppTheme.continuousRect(AppTheme.cornerLarge)
                        .strokeBorder(AppTheme.glassStroke, lineWidth: 1)
                }
        }
        .padding(.horizontal, 28)
    }
}
