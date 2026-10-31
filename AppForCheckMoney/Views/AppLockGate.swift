import SwiftUI

struct AppLockGate: View {
    var onUnlocked: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        ZStack {
            // Subtle brand atmosphere behind the lock — never delays Face ID.
            AtmosphereBackground()
                .overlay {
                    Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
                        .ignoresSafeArea()
                }

            VStack(spacing: 20) {
                Text(L10n.string("app.name"))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

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
            .quietGlassSurface(corner: AppTheme.cornerLarge)
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
