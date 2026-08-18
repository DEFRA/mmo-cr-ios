import SwiftUI

/// The "Gear used" row on the Settings screen: label, current value (or an authored
/// empty-state string), and a trailing "Change" link — see
/// docs/design-specs/settings.md (deviation #5: never render the Figma mock's literal
/// placeholder "Cell").
struct SettingsValueRow: View {
    let label: String
    /// `nil` renders `emptyStateValue` instead, so the caller never has to remember to
    /// substitute the empty-state copy itself.
    let value: String?
    let emptyStateValue: String
    let changeTitle: String
    let changeAccessibilityIdentifier: String
    let onChange: () -> Void

    /// The text actually rendered for the value — pure so it can be unit tested without
    /// standing up a view.
    static func displayValue(_ value: String?, emptyStateValue: String) -> String {
        guard let value, !value.isEmpty else { return emptyStateValue }
        return value
    }

    private var displayValue: String {
        Self.displayValue(value, emptyStateValue: emptyStateValue)
    }

    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .contain)
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
