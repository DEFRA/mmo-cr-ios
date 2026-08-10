import SwiftUI

/// Minimal placeholder destination ending Part 1 of the "Create a catch record" journey.
///
/// Future phases replace this with the next real screen in the journey; kept intentionally
/// simple (no view model) since it has no state or behaviour yet.
struct PlaceholderNextStepView: View {

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        ViewTemplate(title: "") {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                LocalizedText("catchRecord.caption")
                    .font(AppTypography.pageCaption)
                    .foregroundStyle(AppColors.govBlue)

                TitleText(text: languageStore.localized("catchRecord.placeholder.nextStep.heading"))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("CatchRecord.placeholderNextStep.heading")

                ParagraphText(text: languageStore.localized("catchRecord.placeholder.nextStep.message"))
            }
            .environment(\.locale, languageStore.language.locale)
        }
    }
}

#Preview {
    PlaceholderNextStepView()
        .environment(AppLanguageStore.preview)
}
