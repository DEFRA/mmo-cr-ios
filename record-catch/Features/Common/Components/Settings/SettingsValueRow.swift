import SwiftUI
/// A labelled row with a value and a trailing "Change" link — used by the "Gear used" row on the
/// Settings screen and by every row on the "Manage your account" screen — see
/// docs/design-specs/settings.md (deviation #5: never render the Figma mock's literal placeholder
/// "Cell") and docs/design-specs/manage-account.md (field name / value / "Change" link, left to
/// right).
struct SettingsValueRow: View {
    let label: String
    /// `nil` renders `emptyStateValue` instead, so the caller never has to remember to
    /// substitute the empty-state copy itself.
    let value: String?
    let emptyStateValue: String
    let changeTitle: String
    let changeAccessibilityIdentifier: String
    /// Whether `label`, `displayValue` and the "Change" link sit on one row (label — value —
    /// Change, left to right) rather than the label stacked above a value-and-Change row. `true`
    /// matches the "Manage your account" design (see docs/design-specs/manage-account.md); `false`
    /// keeps the Settings "Gear used" row exactly as it was.
    ///
    /// Either layout falls back to a stacked, wrapping arrangement at accessibility Dynamic Type
    /// sizes (`.accessibility1` and above) so a long field name, value and "Change" link never
    /// get clipped or forced to overlap at the largest text sizes (WCAG 2.2 AA).
    var isInlineLayout: Bool = false
    let onChange: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The text actually rendered for the value — pure so it can be unit tested without
    /// standing up a view.
    static func displayValue(_ value: String?, emptyStateValue: String) -> String {
        guard let value, !value.isEmpty else { return emptyStateValue }
        return value
    }
    private var displayValue: String {
        Self.displayValue(value, emptyStateValue: emptyStateValue)
    }

    private var useInlineLayout: Bool {
        isInlineLayout && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if useInlineLayout {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(label)
                        .font(AppTypography.bodySmall.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(displayValue)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    changeLink
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                        Text(label)
                            .font(AppTypography.bodySmall.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                    }
                    HStack(spacing: AppSpacing.small) {
                        Text(displayValue)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        changeLink
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .contain)
    }

    private var changeLink: some View {
        Button(action: onChange) {
            Text(changeTitle)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.linkText)
                .underline()
                .frame(minHeight: AppControlSize.minTapTarget, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(changeAccessibilityIdentifier)
        .accessibilityLabel("\(changeTitle) \(label.lowercased())")
        .accessibilityAddTraits(.isButton)
    }
}
#Preview("Populated") {
    SettingsValueRow(
        label: "Gear used",
        value: "Seine nets",
        emptyStateValue: "Not yet recorded",
        changeTitle: "Change",
        changeAccessibilityIdentifier: "Settings.gearUsed.change",
        onChange: {}
    )
    .padding()
}
#Preview("Empty state") {
    SettingsValueRow(
        label: "Gear used",
        value: nil,
        emptyStateValue: "Not yet recorded",
        changeTitle: "Change",
        changeAccessibilityIdentifier: "Settings.gearUsed.change",
        onChange: {}
    )
    .padding()
}
#Preview("Inline layout — Manage your account") {
    SettingsValueRow(
        label: "First name",
        value: "Jane",
        emptyStateValue: "Not provided",
        changeTitle: "Change",
        changeAccessibilityIdentifier: "ManageAccount.change.firstName",
        isInlineLayout: true,
        onChange: {}
    )
    .padding()
}
#Preview("Max Dynamic Type") {
    SettingsValueRow(
        label: "Gear used",
        value: nil,
        emptyStateValue: "Not yet recorded",
        changeTitle: "Change",
        changeAccessibilityIdentifier: "Settings.gearUsed.change",
        onChange: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
#Preview("Inline layout — Max Dynamic Type (falls back to stacked)") {
    SettingsValueRow(
        label: "First name",
        value: "Jane",
        emptyStateValue: "Not provided",
        changeTitle: "Change",
        changeAccessibilityIdentifier: "ManageAccount.change.firstName",
        isInlineLayout: true,
        onChange: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
