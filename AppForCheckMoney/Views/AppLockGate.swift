import SwiftUI

struct AppLockGate: View {
    var onUnlocked: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.primary)

                Text(L10n.string("app.name"))
                    .font(.title2.weight(.semibold))

                Text(L10n.string("lock.subtitle"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if failed {
                    Text(L10n.string("lock.failed"))
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }

                GlassActionButton(
                    title: busy ? L10n.string("lock.unlocking") : AppLockService.biometryLabel,
                    systemImage: "faceid"
                ) {
                    Task { await unlock() }
                }
                .disabled(busy)
                .opacity(busy ? 0.6 : 1)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                            .strokeBorder(AppTheme.glassStroke(colorScheme), lineWidth: 1)
                    }
            }
            .padding(24)
        }
        .task {
            await unlock()
        }
    }

    private func unlock() async {
        guard !busy else { return }
        busy = true
        failed = false
        let ok = await AppLockService.authenticate(reason: L10n.string("lock.reason"))
        busy = false
        if ok {
            onUnlocked()
        } else {
            failed = true
        }
    }
}
