import SwiftUI

/// GOV.UK Design System "Warning text" component
/// (https://design-system.service.gov.uk/components/warning-text/): an exclamation mark in a
/// filled circle, paired with bold text — no bordered box or coloured banner.
///
/// Deliberately distinct from `WarningBox` (the bordered, blue-banner "Important" callout used on
/// Home/`TripDateView`): this is the lighter-weight inline pattern used where a boxed callout would
/// be visually too heavy for the context — e.g. `SubmissionSavedView`, whose Figma design shows
/// this exact icon-plus-bold-text treatment sitting directly in the page flow beneath the
/// confirmation panel, not inside its own box (see the figma-design instructions' "build as
/// designed" rule).
///
/// The icon never carries the meaning alone (WCAG 1.4.1 "Use of Colour/Shape"): it is
/// `accessibilityHidden`, and the combined VoiceOver label is still prefixed by `tagKey`
/// ("Important") even though that word is not rendered visually here — reusing
/// `WarningBox.accessibilityLabel` so both components announce identically.
struct InlineWarningText: View {
    let tagKey: String
    let messageKey: String

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityHidden(true)

            LocalizedText(messageKey)
                .font(AppTypography.warningBox)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            WarningBox.accessibilityLabel(
                tag: languageStore.localized(tagKey),
                message: languageStore.localized(messageKey)
            )
        )
    }
}

#Preview {
    InlineWarningText(tagKey: "home.warning.tag", messageKey: "home.warning.message")
        .padding()
        .environment(AppLanguageStore.preview)
}
