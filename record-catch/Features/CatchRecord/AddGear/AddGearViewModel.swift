import Foundation

/// View model for the Add-gear screen (type-to-search a gear).
///
/// UI-shaped but backed by a stubbed, API-shaped provider (see ADR-0004). On a valid selection it
/// routes to the measurements screen for that gear (which saves it to favourites). Only Seine nets
/// is available in this phase.
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
    private(set) var didAttemptSubmit = false

    /// Gears available to the search field (loaded from the gear provider).
    private(set) var gears: [GearOption] = []

    private let router: CatchRecordRouter
    private let gearSearch: GearSearchProviding

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        gearSearch: GearSearchProviding = StubGearSearchProvider()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.gearSearch = gearSearch
    }

    /// Gear names shown in the search field.
    var gearNames: [String] { gears.map(\.name) }

    /// The `GearOption` matching the selected name, if any.
    var selectedGear: GearOption? {
        guard let selectedName else { return nil }
        return gears.first { $0.name == selectedName }
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return AddGearValidation.errorKey(for: selectedGear)
    }

    /// Loads the searchable gear list up front so the field can filter locally.
    func loadGears() async {
        gears = (try? await gearSearch.allGears()) ?? []
    }

    /// Validates, then routes to the measurements screen for the selected gear.
    func submit() {
        didAttemptSubmit = true
        guard let gear = selectedGear else { return }
        router.push(.gearMeasurements(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
    }
}
