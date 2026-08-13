import SwiftUI

/// "Your catch record has been submitted" — the final screen in the "Create a catch record"
/// journey, reached once the (stubbed) submission API call on the Confirmation screen succeeds.
///
/// Leads with the green `ConfirmationPanel`, then a "What happens next" bullet list, and a single
/// "View your catch records" action that returns to Home (`popToRoot()`) — there is nothing to go
/// back to once a record has been submitted.
struct SubmissionSuccessView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SubmissionSuccessViewModel

    init(referenceNumber: String, router: CatchRecordRouter) {
        _viewModel = State(wrappedValue: SubmissionSuccessViewModel(referenceNumber: referenceNumber, router: router))
    }

    private let identifierPrefix = "CatchRecord.submissionSuccess"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            ConfirmationPanel(
                headingKey: "catchRecord.submissionSuccess.heading",
                referenceLabelKey: "catchRecord.submissionSuccess.referenceLabel",
                referenceNumber: viewModel.referenceNumber,
                accessibilityIdentifierPrefix: identifierPrefix
            )

            Text(languageStore.localized("catchRecord.submissionSuccess.whatHappensNext"))
                .font(AppTypography.footerHeading)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).whatHappensNextHeading")

            bulletList

            PrimaryButton(title: languageStore.localized("catchRecord.submissionSuccess.viewRecords")) {
                viewModel.viewCatchRecords()
            }
            .accessibilityIdentifier("\(identifierPrefix).viewRecords")
        }
    }

    /// The four bullet points explaining what happens next.
    private var bulletList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            bulletRow(languageStore.localized("catchRecord.submissionSuccess.bullet.received"))
            bulletRow(languageStore.localized("catchRecord.submissionSuccess.bullet.email"))
            bulletRow(languageStore.localized("catchRecord.submissionSuccess.bullet.view"))
            bulletRow(languageStore.localized("catchRecord.submissionSuccess.bullet.save"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix).bulletList")
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
    SubmissionSuccessView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SubmissionSuccessView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SubmissionSuccessView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
