import Foundation

/// View model for the "Remove a species" screen.
///
/// Lists the species already saved to this gear's catch in the journey draft
/// (`draft.gearCatches[…].speciesCaught` — see ADR-0011), lets the user tick one or more to remove,
/// then either "Delete" (validated, then confirmed via a destructive confirmation dialog — see
/// `DraftActionViewModel` for the mirrored pattern) or "Cancel" (pops back with no changes).
///
/// Removing a species here only affects **this gear's** recorded catch; it does not remove the
/// species from the shared favourites store, since the same species may still be used for another
/// gear's catch or a future trip.
@MainActor
@Observable
final class RemoveSpeciesViewModel {

    /// The gear whose recorded catch this screen removes species from.
    let gear: GearOption
    /// Selected vessel name, threaded onward for the Add-species header when the last species is
    /// removed.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The species currently saved to this gear's catch, captured at load time.
    private(set) var species: [SpeciesOption] = []
    /// The ids of the ticked species to remove.
    var selectedIDs: Set<String> = []
    /// String Catalog key for the inline "select at least one" validation error; `nil` hides it.
    private(set) var errorKey: String?
    /// Whether the destructive confirmation dialog is presented, following "Delete".
    private(set) var showDeleteConfirmation = false

    private let router: CatchRecordRouter
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        draft: CatchRecordDraft
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
        species = draft.gearCatchIndex(forGearID: gear.id).map { draft.gearCatches[$0].speciesCaught } ?? []
    }

    /// Whether a species is currently ticked for removal.
    func isSelected(_ id: String) -> Bool { selectedIDs.contains(id) }

    /// Toggles a species' ticked state, clearing any validation error once something is ticked.
    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
        if !selectedIDs.isEmpty {
            errorKey = nil
        }
    }

    /// "Delete" tapped: validates a selection was made, then presents the confirmation dialog.
    /// Does not mutate the draft yet — that happens on `confirmDelete()`.
    func delete() {
        guard !selectedIDs.isEmpty else {
            errorKey = "catchRecord.species.remove.error"
            return
        }
        errorKey = nil
        showDeleteConfirmation = true
    }

    /// Dismisses the confirmation dialog without making any change.
    func cancelDelete() {
        showDeleteConfirmation = false
    }

    /// Confirms the removal: writes the remaining species back into this gear's `GearCatch` entry,
    /// then routes on. When that empties this gear's species list, returns to the Add-species
    /// screen rather than the now-empty weights screen; otherwise returns to the weights screen,
    /// where `RecordSpeciesWeightsViewModel.loadFavourites()` re-seeds from the updated draft.
    func confirmDelete() {
        showDeleteConfirmation = false
        let remaining = species.filter { !selectedIDs.contains($0.id) }
        if let index = draft.gearCatchIndex(forGearID: gear.id) {
            draft.gearCatches[index].speciesCaught = remaining
        }
        species = remaining
        selectedIDs = []

        if remaining.isEmpty {
            router.push(.addSpecies(gear: gear, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights))
        } else {
            router.push(.recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
        }
    }

    /// "Cancel" tapped: returns to the weights screen with no changes to the draft.
    func cancel() {
        router.pop()
    }
}
