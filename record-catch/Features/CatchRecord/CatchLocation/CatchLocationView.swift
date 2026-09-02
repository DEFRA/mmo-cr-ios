import MapKit
import SwiftUI

/// "Where was most of your catch caught using <gear>?" — pick a single statistical area on a map.
///
/// Renders the shared journey chrome (caption, reference number, heading, hints) then the
/// `OfflineMapView` map component for area selection; its cartographic style intentionally need
/// not match the design mock. "Save and continue" validates that an area was chosen and routes on.
struct CatchLocationView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: CatchLocationViewModel
    /// Bridges `OfflineMapView`'s `SubrectangleProperties?` selection to the view model's plain
    /// `selectedArea: String?` (the only part of the selection the rest of the journey needs —
    /// see `CatchRecordDraft.statisticalArea`).
    @State private var selectedSubrectangle: SubrectangleProperties?

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: CatchLocationViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: favouriteSpecies,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.catchLocation"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
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

            ParagraphText(text: languageStore.localized("catchRecord.catchLocation.hint.nearest"))
            ParagraphText(text: languageStore.localized("catchRecord.catchLocation.hint.select"))

            map

            selectedAreaReadout

            if viewModel.errorKey != nil {
                errorBanner
            }

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    private var map: some View {
        OfflineMapView(
            initialCoordinate: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
            initialSpan: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0),
            selectedSubrectangle: Binding(
                get: { selectedSubrectangle },
                set: { newValue in
                    selectedSubrectangle = newValue
                    viewModel.selectedArea = newValue?.subCode
                }
            )
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("\(identifierPrefix).map")
        .onAppear {
            // Reflects any pre-existing selection (e.g. returning via a "Change" link) back into
            // the map's own selection state — see `SubrectangleProperties` doc comment: only
            // `subCode` is guaranteed, which is all the renderer needs to highlight it.
            if let existingArea = viewModel.selectedArea, selectedSubrectangle == nil {
                selectedSubrectangle = SubrectangleProperties(
                    subCode: existingArea,
                    icesName: nil,
                    areaKM2: nil,
                    statX: nil,
                    statY: nil
                )
            }
        }
    }

    @ViewBuilder
    private var selectedAreaReadout: some View {
        let value = viewModel.selectedArea ?? languageStore.localized("catchRecord.catchLocation.selectedArea.none")
        Text(String(format: languageStore.localized("catchRecord.catchLocation.selectedArea"), value))
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityIdentifier("\(identifierPrefix).selectedArea")
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.catchLocation.heading"),
            viewModel.gear.name
        )
    }

    private var errorBanner: some View {
        let message = languageStore.localized("catchRecord.catchLocation.validation.none")
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
        .accessibilityIdentifier("\(identifierPrefix).error")
    }
}

#Preview("English") {
    CatchLocationView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    CatchLocationView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
