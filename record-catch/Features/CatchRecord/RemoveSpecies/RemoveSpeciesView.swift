import SwiftUI

/// "Remove a species caught with <gear>?" — tick one or more previously-recorded species and
/// either delete them or cancel.
///
/// Reached from "Remove species" on `RecordSpeciesWeightsView`, shown only once this gear's catch
/// has at least one species saved to the draft. "Delete" validates a selection was made, then asks
/// for destructive confirmation (mirrors `DraftActionView`'s delete-draft confirmation) before
/// removing the ticked species from this gear's `GearCatch` entry. When that empties the gear's
/// species list, the journey continues on the Add-species screen instead of the now-empty weights
/// screen; otherwise it returns to the weights screen. "Cancel" goes back with no changes.
struct RemoveSpeciesView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: RemoveSpeciesViewModel

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        draft: CatchRecordDraft
    ) {
        _viewModel = State(wrappedValue: RemoveSpeciesViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.removeSpecies"

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .confirmationDialog(
            languageStore.localized("catchRecord.species.remove.confirm.title"),
            isPresented: Binding(
                get: { viewModel.showDeleteConfirmation },
                set: { if !$0 { viewModel.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageStore.localized("catchRecord.species.remove.confirm.confirm"), role: .destructive) {
                viewModel.confirmDelete()
            }
            .accessibilityIdentifier("\(identifierPrefix).confirmDelete")

            Button(languageStore.localized("catchRecord.species.remove.confirm.cancel"), role: .cancel) {
                viewModel.cancelDelete()
            }
            .accessibilityIdentifier("\(identifierPrefix).cancelDeleteConfirm")
        } message: {
            Text(languageStore.localized("catchRecord.species.remove.confirm.message"))
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

            ParagraphText(text: languageStore.localized("catchRecord.species.remove.body"))

            CheckboxGroup(
                options: viewModel.species.map {
                    CheckboxGroupOption(
                        id: $0.id,
                        title: $0.name,
                        accessibilityIdentifier: "\(identifierPrefix).option.\($0.id.lowercased())"
                    )
                },
                selectedIDs: Binding(
                    get: { viewModel.selectedIDs },
                    set: { newValue in
                        // `CheckboxGroup` owns per-option toggling internally via `toggle(_:)`;
                        // mirror that back into the view model so validation-error clearing runs.
                        let toggled = newValue.symmetricDifference(viewModel.selectedIDs)
                        toggled.forEach { viewModel.toggleSelection($0) }
                    }
                ),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).options",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            SecondaryButton(title: languageStore.localized("catchRecord.species.remove.delete")) {
                viewModel.delete()
            }
            .accessibilityIdentifier("\(identifierPrefix).delete")

            LinkButton(title: languageStore.localized("catchRecord.species.remove.cancel")) {
                viewModel.cancel()
            }
            .accessibilityIdentifier("\(identifierPrefix).cancel")
        }
    }

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.species.remove.heading"),
            viewModel.gear.name
        )
    }
}

#Preview("English") {
    let draft = CatchRecordDraft()
    draft.gearCatches = [GearCatch(gear: .seineNets, speciesCaught: [.atlanticCod])]
    return RemoveSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: draft
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    let draft = CatchRecordDraft()
    draft.gearCatches = [GearCatch(gear: .seineNets, speciesCaught: [.atlanticCod])]
    return RemoveSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: draft
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    let draft = CatchRecordDraft()
    draft.gearCatches = [GearCatch(gear: .seineNets, speciesCaught: [.atlanticCod])]
    return RemoveSpeciesView(
        gear: .seineNets,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: draft
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
