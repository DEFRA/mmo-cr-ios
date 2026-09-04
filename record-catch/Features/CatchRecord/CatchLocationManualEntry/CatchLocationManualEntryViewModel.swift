import Foundation

/// View model for the manual "Enter the statistical sub area…" screen (type-to-search a
/// subrectangle code), reached from `CatchLocationView`'s "Other" button.
///
/// A parallel entry point to `CatchLocationViewModel` for the same statistical-area decision:
/// instead of tapping the map, the user searches for the code directly. Shares the same
/// validation rule (`CatchLocationValidation`) and the same "enter species sub-journey" routing
/// (`SpeciesSubJourneyEntry`) as the map screen, so both paths behave identically once an area is
/// chosen.
@MainActor
@Observable
final class CatchLocationManualEntryViewModel {

    /// The gear this location applies to — supplies the "using <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward unchanged.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The current search text.
    var query: String = ""
    /// The subrectangle code selected from the results list (nil until one is chosen).
    var selectedCode: String?
    private(set) var didAttemptSubmit = false

    /// Subrectangle codes available to the search field, loaded from the search provider.
    private(set) var codes: [String] = []

    private let router: CatchRecordRouter
    private let subrectangleSearch: SubrectangleSearchProviding
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the selected area is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        subrectangleSearch: SubrectangleSearchProviding = BundledSubrectangleSearchProvider(),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.subrectangleSearch = subrectangleSearch
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
    }

    /// Current inline error, once a submit has been attempted. Reuses `CatchLocationValidation` —
    /// the rule ("an area must be chosen") is identical to the map screen.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return CatchLocationValidation.errorKey(for: selectedCode)
    }

    /// Loads the searchable code list up front so the field can filter locally. Failures leave the
    /// list empty (the search simply returns no results) rather than blocking the screen.
    func loadCodes() async {
        codes = (try? await subrectangleSearch.allCodes()) ?? []
    }

    /// Validates "Save and continue" and, when a code has been selected, enters the species
    /// sub-journey — mirrors `CatchLocationViewModel.submit()`.
    func submit() {
        didAttemptSubmit = true
        guard CatchLocationValidation.errorKey(for: selectedCode) == nil else { return }
        draft.statisticalArea = selectedCode
        Task { await enterSpeciesSubJourney() }
    }

    /// Enters the species sub-journey once a code has been chosen — delegates to the shared
    /// `SpeciesSubJourneyEntry` helper (also used by `CatchLocationViewModel`).
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
