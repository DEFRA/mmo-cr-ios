import SwiftUI

/// "Enter the statistical sub area where most of your catch was caught using <gear>" — manual,
/// type-to-search alternative to tapping the map (`CatchLocationView`'s "Other" button).
///
/// Uses the standard `SearchDropdownField` component, mirroring `AddPortView`'s layout. On "Save
/// and continue" the selection is validated (an area must be chosen — same rule as the map
/// screen) and the journey continues into the same species sub-journey.
struct CatchLocationManualEntryView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: CatchLocationManualEntryViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: CatchLocationManualEntryViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.catchLocationManualEntry"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadCodes() }
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

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            SearchDropdownField(
                label: heading,
                placeholder: languageStore.localized("catchRecord.manualEntry.search.placeholder"),
                options: viewModel.codes,
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                selectedOption: Binding(get: { viewModel.selectedCode }, set: { viewModel.selectedCode = $0 }),
                didAttemptSubmit: viewModel.didAttemptSubmit,
                errorMessage: languageStore.localized("catchRecord.catchLocation.validation.none"),
                resultsAnnouncement: { count in
                    count == 0
                        ? languageStore.localized("catchRecord.manualEntry.search.noResults")
                        : String(format: languageStore.localized("catchRecord.manualEntry.search.resultCount"), count)
                }
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.manualEntry.heading"),
            viewModel.gear.name
        )
    }
}

#Preview("English") {
    CatchLocationManualEntryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    CatchLocationManualEntryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    CatchLocationManualEntryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
