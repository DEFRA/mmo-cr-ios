import SwiftUI

/// "Which species did you catch with <gear>?" — tick species and enter their live weights.
///
/// Shown when the user already has favourite species. Each favourite is a checkbox; ticking it
/// reveals the "weight above minimum size retained" field, with links to add/remove the optional
/// "below minimum" and "legally discarded" weight fields. "Add a species" opens the search screen;
/// "Save and continue" records the weights and routes to the summary. Mirrors `SelectGearView` but
/// interleaves per-species weight fields, so it composes `CheckboxOption` directly.
struct RecordSpeciesWeightsView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: RecordSpeciesWeightsViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: RecordSpeciesWeightsViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.recordSpeciesWeights"

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

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.species.record.body"))

            ForEach(viewModel.favourites) { species in
                speciesRow(species)
            }

            LinkButton(title: languageStore.localized("catchRecord.species.record.addSpecies")) {
                viewModel.addSpecies()
            }
            .accessibilityIdentifier("\(identifierPrefix).addSpecies")

            // Dummy link for now — remove-species behaviour is not yet implemented.
            LinkButton(title: languageStore.localized("catchRecord.species.record.removeSpecies")) {
            }
            .accessibilityIdentifier("\(identifierPrefix).removeSpecies")

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
                weightFields(for: species, idKey: idKey)
                    .padding(.leading, AppSpacing.medium)
            }
        }
    }

    @ViewBuilder
    private func weightFields(for species: SpeciesOption, idKey: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            TextInputField(
                label: languageStore.localized("catchRecord.species.weight.above"),
                isRequired: false,
                keyboardType: .decimalPad,
                text: Binding(
                    get: { viewModel.aboveEntries[species.id] ?? "" },
                    set: { viewModel.aboveEntries[species.id] = $0 }
                )
            )
            .accessibilityIdentifier("\(identifierPrefix).weightAbove.\(idKey)")

            if viewModel.isBelowRevealed(species.id) {
                TextInputField(
                    label: languageStore.localized("catchRecord.species.weight.below"),
                    isRequired: false,
                    keyboardType: .decimalPad,
                    text: Binding(
                        get: { viewModel.belowEntries[species.id] ?? "" },
                        set: { viewModel.belowEntries[species.id] = $0 }
                    )
                )
                .accessibilityIdentifier("\(identifierPrefix).weightBelow.\(idKey)")

                LinkButton(title: languageStore.localized("catchRecord.species.weight.below.remove")) {
                    viewModel.removeBelow(species.id)
                }
                .accessibilityIdentifier("\(identifierPrefix).removeBelow.\(idKey)")
            } else {
                LinkButton(title: languageStore.localized("catchRecord.species.weight.below.add")) {
                    viewModel.revealBelow(species.id)
                }
                .accessibilityIdentifier("\(identifierPrefix).addBelow.\(idKey)")
            }

            if viewModel.isDiscardedRevealed(species.id) {
                TextInputField(
                    label: languageStore.localized("catchRecord.species.weight.discarded"),
                    isRequired: false,
                    keyboardType: .decimalPad,
                    text: Binding(
                        get: { viewModel.discardedEntries[species.id] ?? "" },
                        set: { viewModel.discardedEntries[species.id] = $0 }
                    )
                )
                .accessibilityIdentifier("\(identifierPrefix).weightDiscarded.\(idKey)")

                LinkButton(title: languageStore.localized("catchRecord.species.weight.discarded.remove")) {
                    viewModel.removeDiscarded(species.id)
                }
                .accessibilityIdentifier("\(identifierPrefix).removeDiscarded.\(idKey)")
            } else {
                LinkButton(title: languageStore.localized("catchRecord.species.weight.discarded.add")) {
                    viewModel.revealDiscarded(species.id)
                }
                .accessibilityIdentifier("\(identifierPrefix).addDiscarded.\(idKey)")
            }
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.species.record.heading"),
            viewModel.gear.name
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

#Preview("English") {
    RecordSpeciesWeightsView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.atlanticCod])
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    RecordSpeciesWeightsView(
        gear: .seineNets,
        vessel: "ACHILLES",
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
    RecordSpeciesWeightsView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.atlanticCod])
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
