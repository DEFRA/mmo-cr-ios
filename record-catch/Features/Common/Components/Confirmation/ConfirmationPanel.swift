import SwiftUI

/// GOV.UK-style "confirmation panel": a solid green banner used at the top of a submission/
/// application "complete" screen (mirrors the GOV.UK Design System Panel component), announcing
/// success and a reference number the user should keep for their records.
///
/// Reusable across any future confirmation-style screen in the app — not tied to a single
/// feature — so it lives alongside the other shared `DesignSystem`/`Components` building blocks.
/// Copy is routed through the language store like every other component; the reference number
/// itself is a display-only value (not user copy) so it is passed as a raw `String`.
struct ConfirmationPanel: View {

    let headingKey: String
    let referenceLabelKey: String
    let referenceNumber: String
    /// Namespaces the panel's accessibility identifiers for the screen it's used on, e.g.
    /// `"CatchRecord.submissionSuccess"`.
    let accessibilityIdentifierPrefix: String

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            LocalizedText(headingKey)
                .font(AppTypography.pageTitle)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: AppSpacing.xSmall) {
                LocalizedText(referenceLabelKey)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.white)
                Text(referenceNumber)
                    .font(AppTypography.body.weight(.bold))
                    .foregroundStyle(Color.white)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.large)
        .background(AppColors.govGreen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Self.accessibilityLabel(
                heading: languageStore.localized(headingKey),
                referenceLabel: languageStore.localized(referenceLabelKey),
                referenceNumber: referenceNumber
            )
        )
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).panel")
    }

    /// Composes the combined VoiceOver label, e.g. "Your catch record has been submitted. Your
    /// catch record reference A1234520260727150815". Pure and static so it can be unit tested
    /// without a view host.
    static func accessibilityLabel(heading: String, referenceLabel: String, referenceNumber: String) -> String {
        "\(heading). \(referenceLabel) \(referenceNumber)"
    }
}

#Preview("English") {
    ConfirmationPanel(
        headingKey: "catchRecord.submissionSuccess.heading",
        referenceLabelKey: "catchRecord.submissionSuccess.referenceLabel",
        referenceNumber: "A1234520260727150815",
        accessibilityIdentifierPrefix: "CatchRecord.submissionSuccess"
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    ConfirmationPanel(
        headingKey: "catchRecord.submissionSuccess.heading",
        referenceLabelKey: "catchRecord.submissionSuccess.referenceLabel",
        referenceNumber: "A1234520260727150815",
        accessibilityIdentifierPrefix: "CatchRecord.submissionSuccess"
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
