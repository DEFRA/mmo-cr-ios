import SwiftUI

/// "Add species to vessel <VESSEL>" — type-to-search a species and save it to favourites.
///
/// Shown when the user has no favourite species yet, and reached via "Add a species"/"Add another
/// species". On save the chosen species is added to favourites and the journey returns to the
/// appropriate screen (see `AddSpeciesViewModel.completionRoute`). Mirrors `AddPortView`.
struct AddSpeciesView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: AddSpeciesViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        returnPhase: SpeciesReturnPhase,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding
    ) {
        _viewModel = State(wrappedValue: AddSpeciesViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: returnPhase,
            router: router,
            favouriteSpecies: favouriteSpecies
        ))
    }

    private let identifierPrefix = "CatchRecord.addSpecies"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadSpecies() }
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

            ParagraphText(text: languageStore.localized("catchRecord.species.add.empty"))
            ParagraphText(text: languageStore.localized("catchRecord.species.add.body"))

            SearchDropdownField(
                label: heading,
                placeholder: languageStore.localized("catchRecord.species.add.search.placeholder"),
                options: viewModel.speciesNames,
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                selectedOption: Binding(get: { viewModel.selectedName }, set: { viewModel.selectedName = $0 }),
                errorMessage: languageStore.localized("catchRecord.species.add.search.select"),
                resultsAnnouncement: { count in
                    count == 0
                        ? languageStore.localized("catchRecord.species.add.search.noResults")
                        : String(format: languageStore.localized("catchRecord.species.add.search.resultCount"), count)
                }
            )
            // No container-level `.accessibilityIdentifier` here: applying one to the whole
            // `SearchDropdownField` overrides each result row's own explicit identifier — see
            // `AddPortView`'s equivalent comment for the root-cause detail.

            LinkButton(title: languageStore.localized("catchRecord.species.add.mistakenLink")) {
                // Reference content link — no navigation target in this phase.
            }
            .accessibilityIdentifier("\(identifierPrefix).mistakenLink")

            LinkButton(title: languageStore.localized("catchRecord.species.add.contactLink")) {
                // Help link — no navigation target in this phase.
            }
            .accessibilityIdentifier("\(identifierPrefix).contactLink")

            if viewModel.saveFailed {
                errorBanner
            }

            PrimaryButton(
                title: languageStore.localized("catchRecord.saveContinue"),
                isDisabled: viewModel.isSaving
            ) {
                Task { await viewModel.submit() }
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.species.add.heading"),
            viewModel.vessel
        )
    }

    private var errorBanner: some View {
        let message = languageStore.localized("catchRecord.species.saveFailed")
        return HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(message)")
        .accessibilityIdentifier("\(identifierPrefix).saveError")
    }
}

#Preview("English — no favourites") {
    AddSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        returnPhase: .recordWeights,
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    AddSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        returnPhase: .recordWeights,
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    AddSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        returnPhase: .recordWeights,
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
