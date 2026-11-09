import SwiftUI

/// "Select the statistical sub area where the majority of your catch was caught using <gear>?" —
/// a radio-button list of the statistical sub areas nearest the trip's departure port, plus
/// "Other", reached from `CatchLocationView`'s "Other" button overlaid on the map.
///
/// Built from a supplied Figma design (see `docs/design-specs/create-catch-record.md`): the
/// heading, hint copy and "Other" row reuse the map screen's existing String Catalog keys, and the
/// options are rendered with the shared `RadioGroup` component (GOV.UK Design System Radios
/// pattern), mirroring `LandingStorageView`'s single-question layout.
struct CatchLocationNearestAreasView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: CatchLocationNearestAreasViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: CatchLocationNearestAreasViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.catchLocationNearestAreas"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadAreas() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Text(viewModel.referenceNumber)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("\(identifierPrefix).referenceNumber")

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.catchLocation.hint.nearest"))
            ParagraphText(text: languageStore.localized("catchRecord.catchLocation.hint.select"))
            ParagraphText(text: languageStore.localized("catchRecord.catchLocation.hint.other"))

            RadioGroup(
                options: radioOptions,
                selectedID: selectionBinding,
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).radioGroup",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    /// One `RadioGroupOption` per nearest area, in distance order, followed by "Other" as the
    /// final row — matching the supplied design, which places "Other" last in the same list
    /// rather than separated by a GOV.UK Design System "or" divider (a recorded deviation, see
    /// `docs/design-specs/create-catch-record.md`).
    private var radioOptions: [RadioGroupOption] {
        viewModel.areas.map { code in
            RadioGroupOption(
                id: code,
                title: code,
                accessibilityIdentifier: "\(identifierPrefix).option.\(code)"
            )
        } + [
            RadioGroupOption(
                id: CatchLocationNearestAreasViewModel.otherOptionID,
                title: languageStore.localized("catchRecord.catchLocation.otherButton"),
                accessibilityIdentifier: "\(identifierPrefix).option.other"
            )
        ]
    }

    private var selectionBinding: Binding<String?> {
        Binding(get: { viewModel.selection }, set: { viewModel.selection = $0 })
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.nearestAreas.heading"),
            viewModel.gear.descriptionWithMeasurements(localize: languageStore.localized)
        )
    }
}

#Preview("English") {
    CatchLocationNearestAreasView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: {
            let draft = CatchRecordDraft()
            draft.departurePort = PortOption(
                name: "Plymouth",
                coordinate: PortCoordinate(latitude: 50.3660, longitude: -4.1427)
            )
            return draft
        }()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    CatchLocationNearestAreasView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: {
            let draft = CatchRecordDraft()
            draft.departurePort = PortOption(
                name: "Plymouth",
                coordinate: PortCoordinate(latitude: 50.3660, longitude: -4.1427)
            )
            return draft
        }()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    CatchLocationNearestAreasView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: {
            let draft = CatchRecordDraft()
            draft.departurePort = PortOption(
                name: "Plymouth",
                coordinate: PortCoordinate(latitude: 50.3660, longitude: -4.1427)
            )
            return draft
        }()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
