import SwiftUI

/// "Species caught with <gear> on vessel <VESSEL>" — review recorded species and their weights.
///
/// Lists each recorded species with its captured weights and a "Remove" link, plus "Save and
/// continue" (primary) and "Add another species" (secondary). Mirrors the select screens' button
/// pairing.
struct SpeciesSummaryView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SpeciesSummaryViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: SpeciesSummaryViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.speciesSummary"

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

            ParagraphText(text: languageStore.localized("catchRecord.species.summary.body"))

            ForEach(viewModel.species) { species in
                speciesRow(species)
            }

            VStack(spacing: AppSpacing.small) {
                PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                    viewModel.submit()
                }
                .accessibilityIdentifier("\(identifierPrefix).saveContinue")

                SecondaryButton(title: languageStore.localized("catchRecord.species.summary.addAnother")) {
                    viewModel.addAnother()
                }
                .accessibilityIdentifier("\(identifierPrefix).addAnother")
            }
        }
    }

    @ViewBuilder
    private func speciesRow(_ species: SpeciesOption) -> some View {
        let idKey = species.id.lowercased()
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(species.name)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityIdentifier("\(identifierPrefix).species.\(idKey)")

            ForEach(weightLines(for: species), id: \.self) { line in
                Text(line)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }

            LinkButton(title: languageStore.localized("catchRecord.species.summary.remove")) {
                Task { await viewModel.remove(id: species.id) }
            }
            .accessibilityIdentifier("\(identifierPrefix).remove.\(idKey)")
        }
        .accessibilityElement(children: .contain)
    }

    /// Builds the already-localised "- <label>: <value> kg" lines for a species' captured weights,
    /// skipping any that were not entered.
    private func weightLines(for species: SpeciesOption) -> [String] {
        var lines: [String] = []
        if !species.weightAboveMinimumKg.isEmpty {
            lines.append(line("catchRecord.species.summary.above", species.weightAboveMinimumKg))
        }
        if let below = species.weightBelowMinimumKg, !below.isEmpty {
            lines.append(line("catchRecord.species.summary.below", below))
        }
        if let discarded = species.weightLegallyDiscardedKg, !discarded.isEmpty {
            lines.append(line("catchRecord.species.summary.discarded", discarded))
        }
        return lines
    }

    private func line(_ key: String, _ value: String) -> String {
        String(format: languageStore.localized(key), value)
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.species.summary.heading"),
            viewModel.gear.name,
            viewModel.vessel
        )
    }
}

private extension SpeciesOption {
    /// A fully-recorded Atlantic cod for previews, matching the design mock (250 / 10 / 5 kg).
    static let recordedCod = SpeciesOption(
        id: "Atlantic cod (COD)",
        name: "Atlantic cod (COD)",
        weightAboveMinimumKg: "250",
        weightBelowMinimumKg: "10",
        weightLegallyDiscardedKg: "5"
    )
}

#Preview("English") {
    SpeciesSummaryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.recordedCod])
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SpeciesSummaryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.recordedCod])
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    SpeciesSummaryView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: [.recordedCod])
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
