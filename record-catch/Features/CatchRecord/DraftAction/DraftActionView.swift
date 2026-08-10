import SwiftUI

/// Screen 1 of "Create a catch record": what to do with an existing draft (unsent) record.
struct DraftActionView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: DraftActionViewModel

    init(row: SubmissionRow, router: CatchRecordRouter) {
        _viewModel = State(wrappedValue: DraftActionViewModel(row: row, router: router))
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .confirmationDialog(
            languageStore.localized("catchRecord.draftAction.delete.title"),
            isPresented: Binding(
                get: { viewModel.showDeleteConfirmation },
                set: { if !$0 { viewModel.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageStore.localized("catchRecord.draftAction.delete.confirm"), role: .destructive) {
                viewModel.confirmDelete()
            }
            .accessibilityIdentifier("CatchRecord.draftAction.deleteConfirm")

            Button(languageStore.localized("catchRecord.draftAction.delete.cancel"), role: .cancel) {
                viewModel.cancelDelete()
            }
            .accessibilityIdentifier("CatchRecord.draftAction.deleteCancel")
        } message: {
            Text(languageStore.localized("catchRecord.draftAction.delete.message"))
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            LocalizedText("catchRecord.caption")
                .font(AppTypography.pageCaption)
                .foregroundStyle(AppColors.govBlue)

            TitleText(text: languageStore.localized("catchRecord.draftAction.heading"))
                .accessibilityAddTraits(.isHeader)

            RadioGroup(
                options: [
                    RadioGroupOption(
                        id: DraftActionOption.complete.id,
                        title: languageStore.localized("catchRecord.draftAction.option.complete"),
                        accessibilityIdentifier: "CatchRecord.draftAction.option.complete"
                    ),
                    RadioGroupOption(
                        id: DraftActionOption.delete.id,
                        title: languageStore.localized("catchRecord.draftAction.option.delete"),
                        accessibilityIdentifier: "CatchRecord.draftAction.option.delete"
                    )
                ],
                selectedID: selectionBinding,
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "CatchRecord.draftAction.radioGroup",
                errorAccessibilityIdentifier: "CatchRecord.draftAction.error"
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("CatchRecord.draftAction.saveContinue")
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selection?.id },
            set: { viewModel.selection = $0.flatMap(DraftActionOption.init(rawValue:)) }
        )
    }
}

#Preview("English") {
    DraftActionView(
        row: SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    DraftActionView(
        row: SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
        router: CatchRecordRouter()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    DraftActionView(
        row: SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
