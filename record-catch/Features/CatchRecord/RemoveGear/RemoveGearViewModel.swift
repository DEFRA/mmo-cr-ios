import Foundation

/// View model for the "Remove gear from vessel" screen — adapted for mobile from a supplied web
/// design (see `docs/design-specs/create-catch-record.md`'s Remove-gear deviation register).
///
/// Lists every gear currently saved to the user's favourites (see `FavouriteGearProviding`,
/// ADR-0023), lets the user tick one or more to remove, then "Continue" — validated, then
/// confirmed via a destructive confirmation dialog (mirrors `RemoveSpeciesViewModel`/
/// `DraftActionViewModel`) — permanently deletes them from the on-device favourites store.
///
/// Removal is **on-device only** for now: `VesselFavouritesServicing.removeFavouriteGear` exists on
/// the Catch Recording Service connector (ADR-0025) but, like the rest of the favourites surface, is
/// not yet wired to anything — favourites stay local/offline-first until a future phase connects
/// the whole service (see ADR-0004/ADR-0025 "Update" notes).
///
/// A gear removed here that is already ticked on the current trip's "What gear did you use?"
/// screen is taken out of `CatchRecordDraft.gearCatches` too, so the in-progress record never
/// references a favourite that no longer exists.
@MainActor
@Observable
final class RemoveGearViewModel {

    /// Selected vessel name, shown in the heading ("Remove gear from vessel <VESSEL>").
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The gears currently saved to favourites, captured at load time.
    private(set) var gears: [GearOption] = []
    /// The ids of the ticked gears to remove.
    var selectedIDs: Set<String> = []
    /// String Catalog key for the inline "select at least one" validation error; `nil` hides it.
    private(set) var errorKey: String?
    /// Whether the destructive confirmation dialog is presented, following "Continue".
    private(set) var showRemoveConfirmation = false
    /// Set when removing a gear from favourites fails, so the view can surface a recoverable error
    /// (mirrors `GearMeasurementsViewModel.saveFailed`).
    private(set) var removeFailed = false
    /// Set while a confirmed removal is being saved, so the view can disable "Continue".
    private(set) var isRemoving = false

    private let router: CatchRecordRouter
    private let favouriteGears: FavouriteGearProviding
    /// Shared journey draft; a removed gear is also taken out of this trip's selected gears, if
    /// present (see type doc comment).
    private let draft: CatchRecordDraft

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding,
        draft: CatchRecordDraft
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteGears = favouriteGears
        self.draft = draft
    }

    /// Loads the user's favourite gears for display. Failures leave the list empty.
    func loadFavourites() async {
        gears = (try? await favouriteGears.favouriteGears()) ?? []
    }

    /// Whether a gear is currently ticked for removal.
    func isSelected(_ id: String) -> Bool { selectedIDs.contains(id) }

    /// Toggles a gear's ticked state, clearing any validation error once something is ticked.
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

    /// "Continue" tapped: validates a selection was made, then presents the confirmation dialog.
    /// Does not remove anything yet — that happens on `confirmRemove()`.
    func submit() {
        guard !selectedIDs.isEmpty else {
            errorKey = "catchRecord.gear.remove.validation.none"
            return
        }
        errorKey = nil
        showRemoveConfirmation = true
    }

    /// Dismisses the confirmation dialog without making any change.
    func cancelRemove() {
        showRemoveConfirmation = false
    }

    /// Confirms the removal: deletes every ticked gear from the on-device favourites store, takes
    /// any of them out of the current trip's `CatchRecordDraft.gearCatches`, then routes to the
    /// select-gear screen — or, if that empties favourites entirely, to the Add-gear screen
    /// instead (mirrors `CatchRecordRouting.gearEntryRoute`'s own entry-point rule). A removal
    /// failure (e.g. offline) leaves the ticked selection untouched and surfaces a recoverable
    /// error banner, without routing away from this screen.
    func confirmRemove() async {
        showRemoveConfirmation = false
        isRemoving = true
        defer { isRemoving = false }

        do {
            for id in selectedIDs {
                try await favouriteGears.removeFavourite(id: id)
            }
        } catch {
            removeFailed = true
            return
        }

        draft.gearCatches.removeAll { selectedIDs.contains($0.gear.id) }
        gears.removeAll { selectedIDs.contains($0.id) }
        selectedIDs = []
        removeFailed = false

        router.push(CatchRecordRouting.gearEntryRoute(
            hasFavourites: !gears.isEmpty,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }
}
