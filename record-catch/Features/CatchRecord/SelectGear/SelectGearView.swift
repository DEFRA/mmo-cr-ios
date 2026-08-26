import SwiftUI

/// "What gear did you use?" — tick one or more of the user's favourite gears (multi-select).
///
/// Shown when the user already has favourite gears. Ticking a gear reveals its per-trip **variable**
/// measurement field(s) (e.g. "Number of times gear was shot on trip") beneath the checkbox, using
/// the GOV.UK conditional-reveal pattern. "Save and continue" validates that at least one gear is
/// selected and that each ticked gear's variable measurements are whole numbers; "Add another gear"
/// opens the search screen. Mirrors `SelectPortView` but uses checkboxes for many-of-many selection.
struct SelectGearView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectGearViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: SelectGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favouriteGears,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.selectGear"

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

            TitleText(text: languageStore.localized("catchRecord.selectGear.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.selectGear.hint"))

            CheckboxGroup(
                options: viewModel.favourites.map { gear in
                    CheckboxGroupOption(
                        id: gear.id,
                        title: gear.name,
                        subtitle: measurementSummary(for: gear),
                        accessibilityIdentifier: "\(identifierPrefix).option.\(gear.id.lowercased())"
                    )
                },
                selectedIDs: Binding(get: { viewModel.selection }, set: { viewModel.selection = $0 }),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).checkboxGroup",
                errorAccessibilityIdentifier: "\(identifierPrefix).error",
                revealedContent: { option in variableMeasurementFields(forGearID: option.id) }
            )

            VStack(spacing: AppSpacing.small) {
                PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                    viewModel.submit()
                }
                .accessibilityIdentifier("\(identifierPrefix).saveContinue")

                SecondaryButton(title: languageStore.localized("catchRecord.selectGear.addAnother")) {
                    viewModel.addAnotherGear()
                }
                .accessibilityIdentifier("\(identifierPrefix).addAnother")
            }
        }
    }

    /// The per-trip variable-measurement input fields revealed under a ticked gear.
    @ViewBuilder
    private func variableMeasurementFields(forGearID gearID: String) -> some View {
        if let gear = viewModel.favourites.first(where: { $0.id == gearID }) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(gear.variableMeasurements) { measurement in
                    TextInputField(
                        label: languageStore.localized(measurement.labelKey),
                        keyboardType: .numberPad,
                        text: Binding(
                            get: { viewModel.variableEntries["\(gearID).\(measurement.id)"] ?? "" },
                            set: { viewModel.variableEntries["\(gearID).\(measurement.id)"] = $0 }
                        ),
                        didAttemptSubmit: false,
                        errorMessage: viewModel
                            .variableErrorKey(gearID: gearID, measurementID: measurement.id)
                            .map { languageStore.localized($0) }
                    )
                    .accessibilityIdentifier(
                        "\(identifierPrefix).variable.\(gearID.lowercased()).\(measurement.id)"
                    )
                }
            }
        }
    }

    /// Builds an already-localised one-line summary of a gear's captured required measurements, e.g.
    /// "100mm mesh", or `nil` when it has none.
    private func measurementSummary(for gear: GearOption) -> String? {
        let parts = gear.requiredMeasurements.compactMap { measurement -> String? in
            guard let value = measurement.value else { return nil }
            return String(
                format: languageStore.localized("catchRecord.gear.measurement.meshSize.summary"),
                value
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

#Preview("English") {
    SelectGearView(
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(
            initialFavourites: [GearOption.seineNets.withRequiredMeasurements([
                GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 100)
            ])]
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    SelectGearView(
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(initialFavourites: [.seineNets])
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
