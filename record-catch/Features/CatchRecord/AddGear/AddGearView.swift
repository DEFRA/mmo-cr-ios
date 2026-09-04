import SwiftUI

/// "Add gear to vessel <VESSEL>" — type-to-search a gear used by this vessel.
///
/// Shown when the user has no favourite gears yet, and reached via the select screen's "Add another
/// gear" button. On save the journey continues to the measurements screen for the chosen gear — or,
/// for a gear with no required measurements at all, straight back to the select screen once it has
/// been saved to favourites (see ADR-0012). Mirrors `AddPortView`.
struct AddGearView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: AddGearViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        gearSearch: GearSearchProviding = StubGearSearchProvider(),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider()
    ) {
        _viewModel = State(wrappedValue: AddGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            gearSearch: gearSearch,
            favouriteGears: favouriteGears
        ))
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadGears() }
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
                .accessibilityIdentifier("CatchRecord.addGear.referenceNumber")

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("CatchRecord.addGear.heading")

            ParagraphText(text: languageStore.localized("catchRecord.addGear.body"))

            ParagraphText(text: languageStore.localized("catchRecord.addGear.example"), isHint: true)

            SearchDropdownField(
                label: heading,
                placeholder: languageStore.localized("catchRecord.addGear.search.placeholder"),
                options: viewModel.gearNames,
                query: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                selectedOption: Binding(get: { viewModel.selectedName }, set: { viewModel.selectedName = $0 }),
                didAttemptSubmit: viewModel.didAttemptSubmit,
                errorMessage: languageStore.localized("catchRecord.addGear.validation.none"),
                resultsAnnouncement: { count in
                    count == 0
                        ? languageStore.localized("catchRecord.addGear.search.noResults")
                        : String(format: languageStore.localized("catchRecord.addGear.search.resultCount"), count)
                }
            )
            // No container-level `.accessibilityIdentifier` here: applying one to the whole
            // `SearchDropdownField` overrides each result row's own explicit identifier — see
            // `AddPortView`'s equivalent comment for the root-cause detail.

            if viewModel.saveFailed {
                errorBanner
            }

            PrimaryButton(
                title: languageStore.localized("catchRecord.saveContinue"),
                isDisabled: viewModel.isSaving
            ) {
                Task { await viewModel.submit() }
            }
            .accessibilityIdentifier("CatchRecord.addGear.saveContinue")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.addGear.heading"),
            viewModel.vessel
        )
    }

    private var errorBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            Text(languageStore.localized("catchRecord.gear.measurement.saveFailed"))
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("catchRecord.gear.measurement.saveFailed"))"
        )
        .accessibilityIdentifier("CatchRecord.addGear.saveError")
    }
}

#Preview("English — no favourites") {
    AddGearView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    AddGearView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
