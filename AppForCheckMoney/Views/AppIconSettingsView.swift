import SwiftUI

/// Minimal Liquid Glass sheet to pick Default / Dark / Transparent home-screen icon.
struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = AppIconSettings.current
    @State private var errorMessage: String?
    @State private var isApplying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.string("settings.icon.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    GlassPanel(padding: 8, corner: AppTheme.cornerMedium) {
                        VStack(spacing: 0) {
                            ForEach(AppIconOption.allCases) { option in
                                Button {
                                    Task { await select(option) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: option.symbolName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .frame(width: 28)

                                        Text(L10n.string(option.titleKey))
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if selected == option {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isApplying)

                                if option != AppIconOption.allCases.last {
                                    Divider().opacity(0.25).padding(.leading, 54)
                                }
                            }
                        }
                    }

                    if !AppIconSettings.supportsAlternateIcons {
                        Text(L10n.string("settings.icon.unsupported"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.expense)
                    }
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("settings.icon.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .onAppear { selected = AppIconSettings.current }
        }
    }

    private func select(_ option: AppIconOption) async {
        isApplying = true
        errorMessage = nil
        do {
            try await AppIconSettings.apply(option)
            selected = option
        } catch {
            errorMessage = error.localizedDescription
        }
        isApplying = false
    }
}
