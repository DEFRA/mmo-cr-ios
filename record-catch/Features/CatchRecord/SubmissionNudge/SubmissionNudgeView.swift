import SwiftUI

/// Late-submission nudge screen for the "Create a catch record" journey.
///
/// Shown after a valid trip end (return) date when the trip ended more than 24 hours ago
/// (see `SubmissionNudge`). Information-only: it reminds the user that records must be submitted
/// within 24 hours, offers a "Check the trip end date" link to correct the date, and a
/// "Save and continue" button to acknowledge and continue into the port sub-journey.
struct SubmissionNudgeView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SubmissionNudgeViewModel

    init(
        daysLate: Int,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding
    ) {
        _viewModel = State(wrappedValue: SubmissionNudgeViewModel(
            daysLate: daysLate,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: favouritePorts
        ))
    }

    private let identifierPrefix = "CatchRecord.submissionNudge"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            LocalizedText("catchRecord.caption")
                .font(AppTypography.pageCaption)
                .foregroundStyle(AppColors.govBlue)

            Text(viewModel.referenceNumber)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("\(identifierPrefix).referenceNumber")

            TitleText(text: languageStore.localized("catchRecord.submissionNudge.heading", count: viewModel.daysLate))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            bodyWithLink

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    /// The guidance paragraph, followed by a link that returns to the trip end date screen.
    ///
    /// The link is a real button (not in-string markdown) so it meets the 44×44pt target and
    /// announces its role/label to VoiceOver, Voice Control and Switch Control.
    @ViewBuilder
    private var bodyWithLink: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ParagraphText(text: languageStore.localized("catchRecord.submissionNudge.body"))

            Button {
                viewModel.checkTripEndDate()
            } label: {
                Text(languageStore.localized("catchRecord.submissionNudge.checkDateLink"))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.govBlue)
                    .underline()
                    .frame(minHeight: AppControlSize.minTapTarget, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityAddTraits(.isLink)
            .accessibilityIdentifier("\(identifierPrefix).checkDateLink")
        }
    }
}

#Preview("English") {
    SubmissionNudgeView(daysLate: 3, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SubmissionNudgeView(daysLate: 3, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SubmissionNudgeView(daysLate: 3, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
