import SwiftUI

/// "Your catch record has been saved" — shown instead of `SubmissionSuccessView` when
/// `SubmissionConfirmationViewModel.submit()` detects the device has no connectivity
/// (BR-SUB-008/AC10/AC11).
///
/// Deliberately does **not** reuse `ConfirmationPanel` (the green "success" banner): the record
/// was *not* submitted, so showing the same green panel used for a real submission would convey a
/// false success state by colour alone. Instead this leads with a plain heading and a `WarningBox`
/// — the same "Important" notice component used elsewhere in the app — carrying the message in
/// text, not colour, that the record is saved locally but still needs to be sent once back online.
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
            TitleText(text: languageStore.localized("catchRecord.submissionSaved.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            Text(viewModel.referenceNumber)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("\(identifierPrefix).referenceNumber")

            WarningBox(
                tagKey: "home.warning.tag",
                messageKey: "catchRecord.submissionSaved.body"
            )
            .accessibilityIdentifier("\(identifierPrefix).notice")

            PrimaryButton(title: languageStore.localized("catchRecord.submissionSaved.viewRecords")) {
                viewModel.viewCatchRecords()
            }
            .accessibilityIdentifier("\(identifierPrefix).viewRecords")
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
