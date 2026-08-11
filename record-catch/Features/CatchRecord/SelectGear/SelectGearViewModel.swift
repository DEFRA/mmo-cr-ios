import Foundation

/// View model for the "What gear did you use?" screen.
///
/// Loads the user's favourite gears (offline-first, local source of truth — mirrors ports), lets
/// the user tick one or more, validates the selection, and routes on. "Add another gear" pushes the
/// Add-gear search screen.
@MainActor
@Observable
final class SelectGearViewModel {

    /// Selected vessel name, threaded onward for the Add-gear header.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite gears, loaded from the provider.
    private(set) var favourites: [GearOption] = []
    /// The ids of the ticked gears.
    var selection: Set<String> = []
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouriteGears: FavouriteGearProviding
    /// Shared journey draft; the confirmed gear is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteGears = favouriteGears
        self.draft = draft
    }

    /// Loads favourite gears for display. Failures leave the list empty.
    func loadFavourites() async {
        favourites = (try? await favouriteGears.favouriteGears()) ?? []
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectGearValidation.errorKey(for: selection)
    }

    /// Validates "Save and continue" and routes on when at least one gear is ticked.
    ///
    /// Routes to the catch-location screen for the selected gear (the first, in favourites order,
    /// while only a single gear is implemented) so the user can pick where most of that catch was
    /// caught.
    func submit() {
        didAttemptSubmit = true
        guard !selection.isEmpty else { return }
        guard let gear = favourites.first(where: { selection.contains($0.id) }) else { return }
        draft.gear = gear
        router.push(.catchLocation(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
    }

    /// Routes to the Add-gear search screen.
    func addAnotherGear() {
        router.push(.addGear(vessel: vessel, referenceNumber: referenceNumber))
    }
}
