import SwiftUI
import SwiftData

/// Local UX shell for private / shared spaces. True family sync needs paid Developer + iCloud.
struct SpacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var spaces: [MoneySpace]
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    QuietSectionLabel(text: L10n.string("space.yours"))
                    ForEach(spaces, id: \.id) { space in
                        GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(space.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(space.kind.title)
                                    .font(.caption)
                                    .themeTertiary()
                                if space.isSharedPlaceholder {
                                    Text(L10n.string("space.sharedLocalOnly"))
                                        .font(.caption2)
                                        .themeTertiary()
                                }
                            }
                        }
                    }

                    QuietSectionLabel(text: L10n.string("space.invite"))
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("space.inviteBody"))
                                .font(.footnote)
                                .themeSecondary()
                            Button(L10n.string("space.createSharedPlaceholder")) {
                                createSharedPlaceholder()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    QuietSectionLabel(text: L10n.string("space.syncTitle"))
                    Text(L10n.string("space.syncBody"))
                        .font(.footnote)
                        .themeTertiary()
                    GlassPanel(padding: 14, corner: AppTheme.cornerMedium) {
                        Toggle(L10n.string("icloud.prefer"), isOn: $settings.preferiCloudSync)
                    }
                    Text(L10n.string("space.developerNeeded"))
                        .font(.caption2)
                        .themeTertiary()
                }
                .padding(20)
            }
            .liquidScreen()
            .navigationTitle(L10n.string("space.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .onAppear {
                SeedData.ensureLedgerDefaults(in: modelContext)
            }
        }
    }

    private func createSharedPlaceholder() {
        let code = String(UUID().uuidString.prefix(8)).uppercased()
        modelContext.insert(MoneySpace(
            name: L10n.string("space.familyPlaceholder"),
            kind: .shared,
            inviteCode: code
        ))
        try? modelContext.save()
    }
}
