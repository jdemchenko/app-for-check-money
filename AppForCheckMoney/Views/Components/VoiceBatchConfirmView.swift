import SwiftUI

/// Qalta-like multi-tx voice confirm: wallet chip, quoted phrase, day groups,
/// dual amounts (display + original), Отмена / Сохранить.
struct VoiceBatchConfirmView: View {
    let phrase: String
    let drafts: [VoiceDraft]
    let categories: [MoneyCategory]
    let accounts: [MoneyAccount]
    let displayCurrency: AppCurrency
    let entryCurrency: AppCurrency
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var wallet: MoneyAccount? {
        accounts.first(where: { !$0.isArchived }) ?? accounts.first
    }

    private var dayGroups: [(day: Date, label: String, drafts: [VoiceDraft], totalDisplay: Double)] {
        let cal = Calendar.current
        var buckets: [Date: [VoiceDraft]] = [:]
        var order: [Date] = []
        for draft in drafts {
            let day = cal.startOfDay(for: draft.resolvedDate())
            if buckets[day] == nil {
                order.append(day)
                buckets[day] = []
            }
            buckets[day, default: []].append(draft)
        }
        return order.map { day in
            let items = buckets[day] ?? []
            let total = items.reduce(0.0) { partial, draft in
                let native = draft.amount ?? 0
                let code = draft.currency ?? entryCurrency
                let converted = CurrencyConverter.convert(native, from: code, to: displayCurrency)
                let signed = (draft.type ?? .expense) == .income ? converted : -converted
                return partial + signed
            }
            return (day, dayHeader(day), items, total)
        }
    }

    private var batchTotalDisplay: Double {
        dayGroups.reduce(0) { $0 + $1.totalDisplay }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spaceItem) {
                        walletChip
                        quotedPhrase
                        summaryLine
                        ForEach(Array(dayGroups.enumerated()), id: \.offset) { _, group in
                            daySection(group)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 520)

                Divider().opacity(0.35)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text(L10n.string("common.cancel"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppTheme.touchMin)
                            .modifier(BatchConfirmButtonChrome(emphasized: false, destructive: false))
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text(L10n.string("common.save"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppTheme.touchMin)
                            .modifier(BatchConfirmButtonChrome(emphasized: true, destructive: false))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .modifier(BatchConfirmPanelChrome(
                scheme: colorScheme,
                reduceTransparency: reduceTransparency
            ))
            .padding(.horizontal, AppTheme.pageInset)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .animation(AppTheme.springSoft, value: drafts.count)
    }

    // MARK: - Pieces

    private var walletChip: some View {
        HStack(spacing: 8) {
            Image(systemName: wallet?.symbolName ?? "banknote")
                .font(.footnote.weight(.semibold))
            Text(wallet?.name ?? L10n.string("accounts.title"))
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Text("·")
                .themeTertiary()
            Text((wallet?.currency ?? entryCurrency).code)
                .font(.footnote.monospacedDigit())
                .themeSecondary()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassChip(selected: false)
    }

    private var quotedPhrase: some View {
        Text("«\(phrase)»")
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.92))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .quietGlassSurface(corner: AppTheme.radiusControl)
    }

    private var summaryLine: some View {
        let totalText = MoneyFormat.signed(
            abs(batchTotalDisplay),
            type: batchTotalDisplay >= 0 ? .income : .expense,
            code: displayCurrency
        )
        return Text(
            String(
                format: L10n.string("voice.batchSummary"),
                drafts.count,
                totalText
            )
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.top, 2)
    }

    private func daySection(
        _ group: (day: Date, label: String, drafts: [VoiceDraft], totalDisplay: Double)
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.label)
                    .font(.footnote.weight(.semibold))
                    .themeSecondary()
                Spacer()
                Text(MoneyFormat.signed(
                    abs(group.totalDisplay),
                    type: group.totalDisplay >= 0 ? .income : .expense,
                    code: displayCurrency
                ))
                .font(.footnote.monospacedDigit())
                .themeTertiary()
            }

            ForEach(Array(group.drafts.enumerated()), id: \.offset) { _, draft in
                draftRow(draft)
            }
        }
        .padding(.top, 4)
    }

    private func draftRow(_ draft: VoiceDraft) -> some View {
        let cat = categories.first { $0.id == draft.categoryId }
        let nativeCode = draft.currency ?? entryCurrency
        let native = draft.amount ?? 0
        let displayAmount = CurrencyConverter.convert(native, from: nativeCode, to: displayCurrency)
        let type = draft.type ?? .expense
        let title = cat?.displayName() ?? L10n.string("category.unknown")
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle: String = {
            var parts: [String] = []
            if !note.isEmpty { parts.append(note) }
            if draft.isRecurring {
                parts.append(draft.frequency?.title ?? L10n.string("recurring.monthly"))
            }
            if let account = wallet {
                parts.append(account.name)
            }
            return parts.joined(separator: " · ")
        }()

        return HStack(alignment: .center, spacing: 12) {
            CategoryGlyph(
                symbolName: cat?.symbolName ?? "circle.fill",
                colorHex: cat?.colorHex ?? "8E8E93",
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .themeSecondary()
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.signed(displayAmount, type: type, code: displayCurrency))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(type == .income ? AppTheme.income : Color.primary)
                if nativeCode != displayCurrency {
                    Text(MoneyFormat.signed(native, type: type, code: nativeCode))
                        .font(.caption2.monospacedDigit())
                        .themeTertiary()
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func dayHeader(_ day: Date) -> String {
        let cal = Calendar.current
        let absolute = day.formatted(
            .dateTime.weekday(.abbreviated).day().month(.wide)
        )
        let relative: String
        if cal.isDateInToday(day) {
            relative = L10n.string("date.today")
        } else if cal.isDateInYesterday(day) {
            relative = L10n.string("date.yesterday")
        } else if let before = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: .now)),
                  cal.isDate(day, inSameDayAs: before) {
            relative = L10n.string("date.dayBeforeYesterday")
        } else {
            return absolute
        }
        return "\(absolute) · \(relative)"
    }
}

// MARK: - Chrome (mirrors QuietConfirmPanel, kept local to avoid access-level churn)

private struct BatchConfirmButtonChrome: ViewModifier {
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

private struct BatchConfirmPanelChrome: ViewModifier {
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
