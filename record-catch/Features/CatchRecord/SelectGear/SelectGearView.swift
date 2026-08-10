import SwiftUI

/// "What gear did you use?" — tick one or more of the user's favourite gears (multi-select).
///
/// Shown when the user already has favourite gears. "Save and continue" validates that at least one
/// is selected; "Add another gear" opens the search screen. Mirrors `SelectPortView` but uses
/// checkboxes for many-of-many selection.
struct SelectGearView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectGearViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding
    ) {
        _viewModel = State(wrappedValue: SelectGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favouriteGears
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
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
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

    /// Builds an already-localised one-line summary of a gear's captured measurements, e.g.
    /// "100mm mesh", or `nil` when it has none.
    private func measurementSummary(for gear: GearOption) -> String? {
        let parts = gear.measurements.compactMap { measurement -> String? in
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
            initialFavourites: [GearOption.seineNets.withMeasurements([
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
