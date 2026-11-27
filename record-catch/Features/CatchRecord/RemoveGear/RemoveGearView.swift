import SwiftUI

/// "Remove gear from vessel <vessel>" — tick one or more saved gears and remove them from
/// favourites. Adapted for mobile from a supplied web design (see
/// `docs/design-specs/create-catch-record.md`'s Remove-gear deviation register).
///
/// Reached from "Remove gear" on `SelectGearView`. "Continue" validates that at least one gear is
/// ticked, then asks for destructive confirmation (mirrors `RemoveSpeciesView`) before deleting the
/// ticked gears from the on-device favourites store and routing back to the select/add-gear screen
/// (see `RemoveGearViewModel`).
struct RemoveGearView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: RemoveGearViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding,
        draft: CatchRecordDraft
    ) {
        _viewModel = State(wrappedValue: RemoveGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favouriteGears,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.removeGear"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadFavourites() }
        .confirmationDialog(
            languageStore.localized("catchRecord.gear.remove.confirm.title"),
            isPresented: Binding(
                get: { viewModel.showRemoveConfirmation },
                set: { if !$0 { viewModel.cancelRemove() } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageStore.localized("catchRecord.gear.remove.confirm.confirm"), role: .destructive) {
                Task { await viewModel.confirmRemove() }
            }
            .accessibilityIdentifier("\(identifierPrefix).confirmRemove")

            Button(languageStore.localized("catchRecord.gear.remove.confirm.cancel"), role: .cancel) {
                viewModel.cancelRemove()
            }
            .accessibilityIdentifier("\(identifierPrefix).cancelRemoveConfirm")
        } message: {
            Text(languageStore.localized("catchRecord.gear.remove.confirm.message"))
        }
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

            ParagraphText(text: languageStore.localized("catchRecord.removeGear.hint"))

            CheckboxGroup(
                options: viewModel.gears.map { gear in
                    CheckboxGroupOption(
                        id: gear.id,
                        title: gear.name,
                        subtitle: gear.checklistSubtitle(localize: languageStore.localized),
                        accessibilityIdentifier: "\(identifierPrefix).option.\(gear.id.lowercased())"
                    )
                },
                selectedIDs: Binding(
                    get: { viewModel.selectedIDs },
                    set: { newValue in
                        // `CheckboxGroup` owns per-option toggling internally via `toggle(_:)`;
                        // mirror that back into the view model so validation-error clearing runs
                        // (see `RemoveSpeciesView`'s identical pattern).
                        let toggled = newValue.symmetricDifference(viewModel.selectedIDs)
                        toggled.forEach { viewModel.toggleSelection($0) }
                    }
                ),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).options",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            if viewModel.removeFailed {
                errorBanner
            }

            PrimaryButton(
                title: languageStore.localized("catchRecord.removeGear.continue"),
                isDisabled: viewModel.isRemoving
            ) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).continue")
        }
    }

    private var heading: String {
        String(format: languageStore.localized("catchRecord.removeGear.heading"), viewModel.vessel)
    }

    private var errorBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            Text(languageStore.localized("catchRecord.gear.remove.removeFailed"))
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("catchRecord.gear.remove.removeFailed"))"
        )
        .accessibilityIdentifier("\(identifierPrefix).removeError")
    }
}

#Preview("English") {
    RemoveGearView(
        vessel: "OLGA",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(initialFavourites: [
            GearOption.seineNets.withRequiredMeasurements([
                GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 100)
            ]),
            GearOption(id: "OTB", name: "Bottom otter trawl", requiredMeasurements: [.meshSize, .numberOfTrawlNets])
                .withRequiredMeasurements([
                    GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
                ]),
            GearOption(id: "DRB", name: "Dredge", requiredMeasurements: [.numberOfDredges])
                .withRequiredMeasurements([
                    GearMeasurement(id: "numberOfDredges", labelKey: "catchRecord.gear.measurement.numberOfDredges", value: 2)
                ])
        ]),
        draft: CatchRecordDraft()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    RemoveGearView(
        vessel: "OLGA",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(initialFavourites: [.seineNets]),
        draft: CatchRecordDraft()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    RemoveGearView(
        vessel: "OLGA",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(initialFavourites: [.seineNets]),
        draft: CatchRecordDraft()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
