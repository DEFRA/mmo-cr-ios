import SwiftUI

/// "Confirmation" — the final screen before submitting a completed catch record.
///
/// Reached from "Save and continue" on Check your answers. Explains what submitting confirms
/// (weight accuracy, tolerance levels, enforcement action) and requires an explicit confirmation
/// checkbox before "Accept and submit trip details" continues.
struct SubmissionConfirmationView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SubmissionConfirmationViewModel

    init(referenceNumber: String, router: CatchRecordRouter) {
        _viewModel = State(wrappedValue: SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router))
    }

    private let identifierPrefix = "CatchRecord.submissionConfirmation"
    private static let confirmOptionID = "confirm"

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

            TitleText(text: languageStore.localized("catchRecord.submissionConfirmation.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            importantNotice

            ParagraphText(text: languageStore.localized("catchRecord.submissionConfirmation.body"))

            bulletList

            CheckboxGroup(
                options: [
                    CheckboxGroupOption(
                        id: Self.confirmOptionID,
                        title: languageStore.localized("catchRecord.submissionConfirmation.confirmCheckbox"),
                        accessibilityIdentifier: "\(identifierPrefix).confirmCheckbox"
                    )
                ],
                selectedIDs: confirmedBinding,
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).confirmGroup",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            PrimaryButton(title: languageStore.localized("catchRecord.submissionConfirmation.accept")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).accept")
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
            Text(languageStore.localized("catchRecord.submissionConfirmation.notice"))
                .font(AppTypography.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix).notice")
    }

    /// The three bullet points explaining what submission confirms.
    private var bulletList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            bulletRow(languageStore.localized("catchRecord.submissionConfirmation.bullet.weight"))
            bulletRow(languageStore.localized("catchRecord.submissionConfirmation.bullet.tolerance"))
            bulletRow(languageStore.localized("catchRecord.submissionConfirmation.bullet.action"))
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

    private var confirmedBinding: Binding<Set<String>> {
        Binding(
            get: { viewModel.isConfirmed ? [Self.confirmOptionID] : [] },
            set: { viewModel.isConfirmed = $0.contains(Self.confirmOptionID) }
        )
    }
}

#Preview("English") {
    SubmissionConfirmationView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SubmissionConfirmationView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SubmissionConfirmationView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
