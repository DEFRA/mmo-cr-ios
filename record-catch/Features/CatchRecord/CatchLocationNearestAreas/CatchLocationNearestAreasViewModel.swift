import Foundation

/// View model for "Select the statistical sub area where most of your catch was caught using
/// <gear>?" — a radio-button list of the (up to `areaLimit`) statistical sub areas nearest the
/// trip's departure port, plus "Other", reached from `CatchLocationView`'s "Other" button (built
/// from a supplied Figma design — see `docs/design-specs/create-catch-record.md`).
///
/// The trip's departure port is resolved earlier in the journey and is always known by the time
/// this screen is reachable (there is no path into the catch-location sub-journey without first
/// selecting a departure port — see `CatchRecordCheckpoint.ports`), so `loadAreas()` always has a
/// coordinate to rank against in practice; it still degrades to an empty list (only "Other" shown)
/// rather than crashing if that invariant is ever broken.
///
/// Picking a listed area behaves exactly like tapping it on the map (`CatchLocationViewModel`):
/// writes it into this gear's own `GearCatch` entry and continues into the species sub-journey.
/// Picking "Other" — represented as one more selectable row in the same `RadioGroup`, matching the
/// design — pushes the manual, type-to-search screen instead.
@MainActor
@Observable
final class CatchLocationNearestAreasViewModel {

    /// Sentinel `RadioGroup` selection id for the "Other" row, distinct from every real
    /// subrectangle code (which are always ICES-style alphanumeric codes, never this literal).
    static let otherOptionID = "other"

    /// How many nearest areas to offer, matching the supplied design (9 options plus "Other").
    static let areaLimit = 9

    /// The gear this location applies to — supplies the "using <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward unchanged.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The statistical areas nearest the departure port, nearest first, loaded by `loadAreas()`.
    /// Empty until loaded (or if no departure port/coordinate is known).
    private(set) var areas: [String] = []
    /// The chosen `RadioGroup` option id: either one of `areas`, or `Self.otherOptionID`. `nil`
    /// until a selection is made.
    var selection: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let nearestSubrectangleProvider: NearestSubrectangleProviding
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the selected area is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        nearestSubrectangleProvider: NearestSubrectangleProviding = BundledNearestSubrectangleProvider(),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.nearestSubrectangleProvider = nearestSubrectangleProvider
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return CatchLocationNearestAreasValidation.errorKey(for: selection)
    }

    /// Loads the nearest-areas list for the draft's departure port. Pre-selects this gear's
    /// previously-captured statistical area when it is one of the loaded areas — e.g. when
    /// returning via a "Change" link (mirrors `CatchLocationViewModel`'s pre-fill, ADR-0015
    /// decision #1). A previously-captured area that isn't in the (re-ranked) list is left
    /// unselected rather than guessed at.
    func loadAreas() async {
        guard let coordinate = draft.departurePort?.coordinate else {
            areas = []
            return
        }
        areas = (try? await nearestSubrectangleProvider.nearestCodes(to: coordinate, limit: Self.areaLimit)) ?? []

        let existingArea = draft.gearCatchIndex(forGearID: gear.id).flatMap { draft.gearCatches[$0].statisticalArea }
        if let existingArea, areas.contains(existingArea) {
            selection = existingArea
        }
    }

    /// Validates "Save and continue". With no selection, shows the inline error. With "Other"
    /// selected, pushes the manual type-to-search screen. With an area selected, writes it into
    /// this gear's own `GearCatch` entry (see ADR-0011) and enters the species sub-journey —
    /// mirrors `CatchLocationViewModel.submit()`.
    func submit() {
        didAttemptSubmit = true
        guard CatchLocationNearestAreasValidation.errorKey(for: selection) == nil else { return }

        if selection == Self.otherOptionID {
            router.push(.catchLocationManualEntry(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
            return
        }

        if let index = draft.gearCatchIndex(forGearID: gear.id) {
            draft.gearCatches[index].statisticalArea = selection
        }
        Task { await enterSpeciesSubJourney() }
    }

    /// Enters the species sub-journey once an area has been chosen — delegates to the shared
    /// `SpeciesSubJourneyEntry` helper (also used by `CatchLocationViewModel` and
    /// `CatchLocationManualEntryViewModel`).
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
