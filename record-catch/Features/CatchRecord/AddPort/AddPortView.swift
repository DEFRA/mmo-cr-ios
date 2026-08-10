import SwiftUI

/// "Add port to vessel <VESSEL>" — type-to-search a port and save it to favourites.
///
/// Shown when the user has no favourite ports yet, and reached via a select screen's "Add another
/// port" button. On save the chosen port is added to favourites and the journey returns to the
/// appropriate select screen (see `AddPortViewModel.completionRoute`).
struct AddPortView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: AddPortViewModel

    init(
        vessel: String,
        referenceNumber: String,
        returnPhase: SelectPortPhase?,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding
    ) {
        _viewModel = State(wrappedValue: AddPortViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: returnPhase,
            router: router,
            favouritePorts: favouritePorts
        ))
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadPorts() }
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
                .accessibilityIdentifier("CatchRecord.addPort.referenceNumber")

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("CatchRecord.addPort.heading")

            ParagraphText(text: languageStore.localized("catchRecord.addPort.body"))

            SearchDropdownField(
                label: heading,
                placeholder: languageStore.localized("catchRecord.addPort.search.placeholder"),
                options: viewModel.portNames,
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                selectedOption: Binding(get: { viewModel.selectedName }, set: { viewModel.selectedName = $0 }),
                didAttemptSubmit: viewModel.didAttemptSubmit,
                errorMessage: languageStore.localized("catchRecord.addPort.validation.none"),
                resultsAnnouncement: { count in
                    count == 0
                        ? languageStore.localized("catchRecord.addPort.search.noResults")
                        : String(format: languageStore.localized("catchRecord.addPort.search.resultCount"), count)
                }
            )
            .accessibilityIdentifier("CatchRecord.addPort.search")

            if viewModel.saveFailed {
                errorBanner
            }

            PrimaryButton(
                title: languageStore.localized("catchRecord.saveContinue"),
                isDisabled: viewModel.isSaving
            ) {
                Task { await viewModel.submit() }
            }
            .accessibilityIdentifier("CatchRecord.addPort.saveContinue")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.addPort.heading"),
            viewModel.vessel
        )
    }

    private var errorBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            Text(languageStore.localized("catchRecord.addPort.saveFailed"))
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("catchRecord.addPort.saveFailed"))"
        )
        .accessibilityIdentifier("CatchRecord.addPort.saveError")
    }
}

#Preview("English — no favourites") {
    AddPortView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", returnPhase: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    AddPortView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", returnPhase: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    AddPortView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", returnPhase: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
