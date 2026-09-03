import Foundation

/// View model for the "Where was most of your catch caught using <gear>?" screen.
///
/// The user picks a single statistical area (subzone) on the map. On "Save and continue" the
/// selection is validated (an area must be chosen) and the journey routes on. UI-only for this
/// phase: the chosen area is threaded no further than the placeholder next step, and the map is
/// the existing `SeaMapView` component (its style need not match the design).
@MainActor
@Observable
final class CatchLocationViewModel {

    /// The gear this location applies to — supplies the "using <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward unchanged.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The statistical area (subzone code) tapped on the map, or `nil` until one is chosen.
    var selectedArea: String?
    private(set) var didAttemptSubmit = false

    /// The trip's departure port, read once from the shared journey draft. Lets the map open
    /// framed on that port (see `PortMapCamera`) rather than the whole-UK default view; `nil` when
    /// no port has a known location (or none has been selected yet).
    let departurePort: PortOption?

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the selected area is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
        self.departurePort = draft.departurePort
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return CatchLocationValidation.errorKey(for: selectedArea)
    }

    /// Validates "Save and continue" and, when an area has been selected, enters the species
    /// sub-journey.
    func submit() {
        didAttemptSubmit = true
        guard CatchLocationValidation.errorKey(for: selectedArea) == nil else { return }
        draft.statisticalArea = selectedArea
        Task { await enterSpeciesSubJourney() }
    }

    /// Pushes the manual, type-to-search alternative to tapping the map — reached from the
    /// "Other" button overlaid on the map (see `CatchLocationView.otherButton`).
    func enterManualEntry() {
        router.push(.catchLocationManualEntry(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
    }

    /// Enters the species sub-journey once an area has been chosen — delegates to the shared
    /// `SpeciesSubJourneyEntry` helper (also used by `CatchLocationManualEntryViewModel`).
    func enterSpeciesSubJourney() async {
        await SpeciesSubJourneyEntry.enter(
            router: router,
            favouriteSpecies: favouriteSpecies,
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber
        )
    }
}
