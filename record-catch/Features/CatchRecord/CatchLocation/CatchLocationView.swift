import SwiftUI

/// "Where was most of your catch caught using <gear>?" — pick a single statistical area on a map.
///
/// Renders the shared journey chrome (caption, reference number, heading, hints) then the existing
/// `SeaMapView` map component for area selection; its cartographic style intentionally need not
/// match the design mock. "Save and continue" validates that an area was chosen and routes on.
struct CatchLocationView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: CatchLocationViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter
    ) {
        _viewModel = State(wrappedValue: CatchLocationViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router
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
        SeaMapView(selectedSubzone: Binding(
            get: { viewModel.selectedArea },
            set: { viewModel.selectedArea = $0 }
        ))
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("\(identifierPrefix).map")
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
