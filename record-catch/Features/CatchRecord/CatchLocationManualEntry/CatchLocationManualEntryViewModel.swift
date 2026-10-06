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
    /// Number of "Save and continue" attempts. A monotonic counter rather than a `Bool` so the
    /// shared `SearchDropdownField` can re-announce its error to VoiceOver on every attempt — the
    /// `false → true` edge of a flag fires only once, leaving a VoiceOver user with silence on a
    /// second blank submit.
    private(set) var submitAttempt = 0
    /// Whether a submit has been attempted, derived from `submitAttempt` so every existing call
    /// site and test keeps working unchanged.
    var didAttemptSubmit: Bool { submitAttempt > 0 }

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
        // Pre-fills this gear's previously-captured statistical area when restarting a resumed
        // draft from the beginning (see ADR-0015 decision #1).
        self.selectedCode = draft.gearCatchIndex(forGearID: gear.id).flatMap { draft.gearCatches[$0].statisticalArea }
    }

    /// Current validation message, once a submit has been attempted. Uses this screen's own
    /// two-rule validator rather than the map screen's single-rule `CatchLocationValidation`.
    var validationMessage: ValidationMessage? {
        guard didAttemptSubmit else { return nil }
        return CatchLocationManualEntryValidation.message(query: query, selectedCode: selectedCode)
    }

    /// Loads the searchable code list up front so the field can filter locally. Failures leave the
    /// list empty (the search simply returns no results) rather than blocking the screen.
    func loadCodes() async {
        codes = (try? await subrectangleSearch.allCodes()) ?? []
    }

    /// Validates "Save and continue" and, when a code has been selected, enters the species
    /// sub-journey — mirrors `CatchLocationViewModel.submit()`. Writes the code into this gear's
    /// own `GearCatch` entry (see ADR-0011) rather than a single trip-level field, since the
    /// subrectangle is captured per gear.
    func submit() {
        submitAttempt += 1
        guard CatchLocationManualEntryValidation.message(query: query, selectedCode: selectedCode) == nil else { return }
        if let index = draft.gearCatchIndex(forGearID: gear.id) {
            draft.gearCatches[index].statisticalArea = selectedCode
        }
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
