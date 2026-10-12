import Foundation

/// View model for the Add-gear screen (type-to-search a gear).
///
/// UI-shaped but backed by stubbed, API-shaped providers (see ADR-0004). On a valid selection it
/// either:
/// - routes to the measurements screen, for a gear with required (per-favourite) measurements to
///   capture; or
/// - (a gear with none at all — e.g. "Gear not known", "Miscellaneous gear (diving)") saves it
///   straight to favourites and returns to the select screen, skipping the now-empty measurements
///   screen (see ADR-0012).
@MainActor
@Observable
final class AddGearViewModel {

    /// Selected vessel name, shown in the header ("Add gear to vessel <VESSEL>").
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The current search text.
    var query: String = ""
    /// The gear name selected from the results list (nil until one is chosen).
    var selectedName: String?
    /// Number of "Save and continue" attempts. A monotonic counter rather than a `Bool` so the
    /// shared `SearchDropdownField` can re-announce its error to VoiceOver on every attempt — the
    /// `false → true` edge of a flag fires only once, leaving a VoiceOver user with silence on a
    /// second blank submit.
    private(set) var submitAttempt = 0
    /// Whether a submit has been attempted, derived from `submitAttempt` so every existing call
    /// site and test keeps working unchanged.
    var didAttemptSubmit: Bool { submitAttempt > 0 }
    /// Set while a zero-measurement gear is being saved straight to favourites.
    private(set) var isSaving = false
    /// Set when saving a zero-measurement gear to favourites fails, so the view can surface a
    /// recoverable error (mirrors `GearMeasurementsViewModel.saveFailed`).
    private(set) var saveFailed = false

    /// Gears available to the search field (loaded from the gear provider).
    private(set) var gears: [GearOption] = []

    private let router: CatchRecordRouter
    private let gearSearch: GearSearchProviding
    private let favouriteGears: FavouriteGearProviding

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        gearSearch: GearSearchProviding = StubGearSearchProvider(),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.gearSearch = gearSearch
        self.favouriteGears = favouriteGears
    }

    /// Gear names shown in the search field.
    var gearNames: [String] { gears.map(\.name) }

    /// The `GearOption` matching the selected name, if any.
    var selectedGear: GearOption? {
        guard let selectedName else { return nil }
        return gears.first { $0.name == selectedName }
    }

    /// Current validation message, once a submit has been attempted.
    var validationMessage: ValidationMessage? {
        guard didAttemptSubmit else { return nil }
        return AddGearValidation.message(query: query, selectedGear: selectedGear)
    }

    /// Loads the searchable gear list up front so the field can filter locally.
    func loadGears() async {
        gears = (try? await gearSearch.allGears()) ?? []
    }

    /// Validates the selection, then routes to the measurements screen — or, for a gear with no
    /// required measurements at all, saves it straight to favourites and returns to the select
    /// screen (see ADR-0012).
    func submit() async {
        submitAttempt += 1
        saveFailed = false
        guard AddGearValidation.message(query: query, selectedGear: selectedGear) == nil,
              let gear = selectedGear else { return }

        guard gear.requiredMeasurements.isEmpty else {
            router.push(.gearMeasurements(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            try await favouriteGears.addFavourite(gear)
            router.push(.selectGear(vessel: vessel, referenceNumber: referenceNumber))
        } catch {
            saveFailed = true
        }
    }
}
