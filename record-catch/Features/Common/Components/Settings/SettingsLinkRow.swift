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
    /// Displayed before `title` as plain, non-link text (e.g. "1)") — see
    /// docs/design-specs/settings.md. `nil` renders the row exactly as before (no number), so
    /// non-numbered call sites (none currently) are unaffected. Not read by VoiceOver: the
    /// accessibility label stays just `title`, since the row's position in the list already
    /// conveys its order.
    var number: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                if let number {
                    // Plain text — deliberately NOT styled like `title` below (no link colour or
                    // underline), so VoiceOver/Voice Control/sighted users don't mistake the
                    // number for part of the tappable link text.
                    Text(String(format: "%d)", number))
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                }
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
        SettingsLinkRow(title: "My account", accessibilityIdentifier: "Settings.link.myAccount", number: 1) {}
        Divider()
        SettingsLinkRow(title: "Sign out", accessibilityIdentifier: "Settings.link.signOut", number: 4) {}
    }
    .padding()
}
#Preview("Max Dynamic Type") {
    SettingsLinkRow(title: "Support information", accessibilityIdentifier: "Settings.link.supportInformation", number: 3) {}
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
