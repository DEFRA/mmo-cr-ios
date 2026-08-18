import SwiftUI

/// A single row in the Settings menu's vertical list (My account / Privacy notice /
/// Support information / Sign out) — see docs/design-specs/settings.md.
///
/// Deliberately a plain vertical list row (not a table cell): at accessibility Dynamic
/// Type sizes a table would clip or need horizontal-scroll reflow, whereas a stacked
/// list wraps naturally (see the spec's Dynamic Type note).
///
/// `isEnabled` lets a row render as designed (identically styled to the other links)
/// while being genuinely inert — used by the "Sign out" row, which has no action wired
/// yet (see `SettingsViewModel.signOutTapped()`). An inert row still exposes its
/// `accessibilityLabel` so VoiceOver users can find it, but never implies success.
struct SettingsLinkRow: View {
    let title: String
    let accessibilityIdentifier: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                Text(title)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.linkText)
                    .underline()
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: AppControlSize.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("English") {
    VStack(alignment: .leading, spacing: 0) {
        SettingsLinkRow(title: "My account", accessibilityIdentifier: "Settings.link.myAccount") {}
        Divider()
        SettingsLinkRow(title: "Sign out", accessibilityIdentifier: "Settings.link.signOut") {}
    }
    .padding()
}

#Preview("Max Dynamic Type") {
    SettingsLinkRow(title: "Support information", accessibilityIdentifier: "Settings.link.supportInformation") {}
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
