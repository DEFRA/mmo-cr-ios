import SwiftUI

/// The declaration content shown beneath the summary on "Check your answers" — the bold
/// "By submitting this record…" notice plus the three bullet points explaining what submission
/// confirms (weight accuracy, tolerance levels, enforcement action).
///
/// Ported from the former standalone "Confirmation" screen (see the module README and the ADR-0014
/// amendment): there is no separate confirmation checkbox here — the declaration is informational,
/// and "Accept and submit trip details" itself is the acceptance action (see the GOV.UK Design
/// System "Check answers" pattern: https://design-system.service.gov.uk/patterns/check-answers/).
struct SubmissionDeclarationView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    let identifierPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            importantNotice

            ParagraphText(text: languageStore.localized("catchRecord.checkYourAnswers.declaration.body"))

            bulletList
        }
    }

    /// The bold "By submitting this record…" notice with a leading icon. Meaning is carried by the
    /// text itself (never colour/icon alone), so the icon is purely decorative to VoiceOver.
    private var importantNotice: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityHidden(true)
            Text(languageStore.localized("catchRecord.checkYourAnswers.declaration.notice"))
                .font(AppTypography.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix).declaration.notice")
    }

    /// The three bullet points explaining what submission confirms.
    private var bulletList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            bulletRow(languageStore.localized("catchRecord.checkYourAnswers.declaration.bullet.weight"))
            bulletRow(languageStore.localized("catchRecord.checkYourAnswers.declaration.bullet.tolerance"))
            bulletRow(languageStore.localized("catchRecord.checkYourAnswers.declaration.bullet.action"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix).declaration.bulletList")
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Text("•")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityHidden(true)
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("English") {
    SubmissionDeclarationView(identifierPrefix: "CatchRecord.checkYourAnswers")
        .padding()
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SubmissionDeclarationView(identifierPrefix: "CatchRecord.checkYourAnswers")
        .padding()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}
