import SwiftUI

/// "Which species from this trip are you not landing straight away?" — tick species being kept
/// onboard or in keep pots and enter the weight of each.
///
/// Reached from the "Yes" answer on the landing-storage question. Each favourite species is a
/// checkbox; ticking it reveals the "weight above minimum size kept onboard or in keep pots" field.
/// "Save and continue" records the weights and routes to the placeholder next step. Mirrors
/// `RecordSpeciesWeightsView` but with a single weight field per species.
struct LandingStorageSpeciesView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: LandingStorageSpeciesViewModel

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding
    ) {
        _viewModel = State(wrappedValue: LandingStorageSpeciesViewModel(
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies
        ))
    }

    private let identifierPrefix = "CatchRecord.landingStorageSpecies"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadFavourites() }
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

            TitleText(text: languageStore.localized("catchRecord.landingStorageSpecies.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.landingStorageSpecies.hint"), isHint: true)

            ForEach(viewModel.favourites) { species in
                speciesRow(species)
            }

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

    @ViewBuilder
    private func speciesRow(_ species: SpeciesOption) -> some View {
        let idKey = species.id.lowercased()
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            CheckboxOption(
                title: species.name,
                subtitle: nil,
                isSelected: viewModel.isSelected(species.id)
            ) {
                viewModel.toggleSelection(species.id)
            }
            .accessibilityIdentifier("\(identifierPrefix).option.\(idKey)")

            if viewModel.isSelected(species.id) {
                TextInputField(
                    label: languageStore.localized("catchRecord.landingStorageSpecies.weight"),
                    isRequired: false,
                    keyboardType: .decimalPad,
                    text: Binding(
                        get: { viewModel.weightEntries[species.id] ?? "" },
                        set: { viewModel.weightEntries[species.id] = $0 }
                    )
                )
                .accessibilityIdentifier("\(identifierPrefix).weight.\(idKey)")
                .padding(.leading, AppSpacing.medium)
            }
        }
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

#Preview("English") {
    LandingStorageSpeciesView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.atlanticCod])
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    LandingStorageSpeciesView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.atlanticCod])
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    LandingStorageSpeciesView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.atlanticCod])
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
