import SwiftUI

/// "Add gear to vessel <VESSEL>" — type-to-search a gear used by this vessel.
///
/// Shown when the user has no favourite gears yet, and reached via the select screen's "Add another
/// gear" button. On save the journey continues to the measurements screen for the chosen gear.
/// Mirrors `AddPortView`.
struct AddGearView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: AddGearViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        gearSearch: GearSearchProviding = StubGearSearchProvider()
    ) {
        _viewModel = State(wrappedValue: AddGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            gearSearch: gearSearch
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
            .accessibilityIdentifier("CatchRecord.addGear.search")

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
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
