import SwiftUI

/// "Enter the measurements for <gear>" — capture one whole-number value per required measurement.
///
/// For seine nets this is a single "Mesh size (mm)" field, but the screen renders one field per
/// measurement the gear defines, so gears with several measurements work without redesign. On save
/// the gear is added to favourites and the journey returns to the select screen.
struct GearMeasurementsView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: GearMeasurementsViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: GearMeasurementsViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favouriteGears,
            draft: draft
        ))
    }

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
                .accessibilityIdentifier("CatchRecord.gearMeasurements.referenceNumber")

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("CatchRecord.gearMeasurements.heading")

            ParagraphText(text: languageStore.localized("catchRecord.gear.measurement.hint"))

            ForEach(viewModel.gear.requiredMeasurements) { measurement in
                TextInputField(
                    label: languageStore.localized(measurement.labelKey),
                    keyboardType: .numberPad,
                    text: Binding(
                        get: { viewModel.entries[measurement.id] ?? "" },
                        set: { viewModel.entries[measurement.id] = $0 }
                    ),
                    didAttemptSubmit: viewModel.didAttemptSubmit,
                    errorMessage: viewModel.errorKey(for: measurement)
                        .map { languageStore.localized($0) }
                )
                .accessibilityIdentifier("CatchRecord.gearMeasurements.field.\(measurement.id)")
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
            .accessibilityIdentifier("CatchRecord.gearMeasurements.saveContinue")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.gear.measurement.heading"),
            viewModel.gear.name
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
        .accessibilityIdentifier("CatchRecord.gearMeasurements.saveError")
    }
}

#Preview("English — seine nets") {
    GearMeasurementsView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    GearMeasurementsView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
