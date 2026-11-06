import SwiftUI

/// "Your catch record has been recorded" — shown instead of `SubmissionSuccessView` when
/// `CheckYourAnswersViewModel.submit(isOnline:)` detects the device has no connectivity
/// (BR-SUB-008/AC10/AC11).
///
/// Reuses the shared `ConfirmationPanel` (see that type's doc comment) with
/// `AppColors.govBlue` instead of the green used for a real submission, so the two outcomes are
/// never conveyed by the same colour. Beneath the panel: an explanation that the record will send
/// automatically once back online, a "Check your catch records" link, a `WarningBox` — the same
/// "Important" notice component used elsewhere in the app — carrying the 24-hour reminder in text
/// (not colour), and the "View your catch records" action.
struct SubmissionSavedView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SubmissionSavedViewModel

    init(referenceNumber: String, router: CatchRecordRouter) {
        _viewModel = State(wrappedValue: SubmissionSavedViewModel(referenceNumber: referenceNumber, router: router))
    }

    private let identifierPrefix = "CatchRecord.submissionSaved"

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
                headingKey: "catchRecord.submissionSaved.heading",
                referenceLabelKey: "catchRecord.submissionSaved.referenceLabel",
                referenceNumber: viewModel.referenceNumber,
                accessibilityIdentifierPrefix: identifierPrefix,
                backgroundColor: AppColors.govBlue
            )

            Text(languageStore.localized("catchRecord.submissionSaved.sendHeading"))
                .font(AppTypography.footerHeading)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).sendHeading")

            ParagraphText(text: languageStore.localized("catchRecord.submissionSaved.body"))
                .accessibilityIdentifier("\(identifierPrefix).body")

            checkRecordsLink

            WarningBox(
                tagKey: "home.warning.tag",
                messageKey: "catchRecord.submissionSaved.warning"
            )
            .accessibilityIdentifier("\(identifierPrefix).notice")

            PrimaryButton(title: languageStore.localized("catchRecord.submissionSaved.viewRecords")) {
                viewModel.viewCatchRecords()
            }
            .accessibilityIdentifier("\(identifierPrefix).viewRecords")
        }
    }

    /// "Check your catch records" is a real, separately tappable link (not in-string markdown —
    /// mirrors `SubmissionNudgeView.bodyWithLink`), immediately followed by the explanatory
    /// sentence so the pair reads as one flowing paragraph. Keeping the link a standalone element
    /// means it still meets the 44×44pt target and announces its own role to VoiceOver, Voice
    /// Control and Switch Control, rather than only part of an in-line sentence being tappable.
    @ViewBuilder
    private var checkRecordsLink: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Button {
                viewModel.viewCatchRecords()
            } label: {
                Text(languageStore.localized("catchRecord.submissionSaved.checkRecordsLink"))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.govBlue)
                    .underline()
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: AppControlSize.minTapTarget, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
            .accessibilityIdentifier("\(identifierPrefix).checkRecordsLink")

            ParagraphText(text: languageStore.localized("catchRecord.submissionSaved.checkRecordsBody"))
                .accessibilityIdentifier("\(identifierPrefix).checkRecordsBody")
        }
    }
}

#Preview("English") {
    SubmissionSavedView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SubmissionSavedView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SubmissionSavedView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
