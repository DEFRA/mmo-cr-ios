import Foundation

/// View model for the "Enter the measurements for <gear>" screen.
///
/// Collects one whole-number value per measurement the gear requires (seine nets need only a mesh
/// size, but the model supports several). On save it attaches the values to the gear, adds it to the
/// user's favourites (offline-first, local source of truth), then returns to the select screen so
/// the user can tick it.
@MainActor
@Observable
final class GearMeasurementsViewModel {

    /// The gear whose measurements are being captured.
    let gear: GearOption
    /// Selected vessel name, threaded onward.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// Raw field text, keyed by measurement id.
    var entries: [String: String]
    private(set) var didAttemptSubmit = false
    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    private let router: CatchRecordRouter
    private let favouriteGears: FavouriteGearProviding
    /// Shared journey draft; the gear with its captured measurements is written into it on submit
    /// (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteGears = favouriteGears
        self.draft = draft
        self.entries = Dictionary(uniqueKeysWithValues: gear.requiredMeasurements.map { ($0.id, "") })
    }

    /// The inline error key for a given measurement, once a submit has been attempted.
    func errorKey(for measurement: GearMeasurement) -> String? {
        guard didAttemptSubmit else { return nil }
        return GearMeasurementValidation.errorKey(for: entries[measurement.id] ?? "")
    }

    /// Whether every measurement currently parses to a valid whole number.
    var isValid: Bool {
        gear.requiredMeasurements.allSatisfy { GearMeasurementValidation.parse(entries[$0.id] ?? "") != nil }
    }

    /// The route to return to after saving. Pure and independent of async work, so it is directly
    /// unit-testable.
    var completionRoute: CatchRecordRoute {
        .selectGear(vessel: vessel, referenceNumber: referenceNumber)
    }

    /// Validates, attaches values, saves the gear to favourites, then returns to the select screen.
    func submit() async {
        didAttemptSubmit = true
        saveFailed = false
        guard isValid else { return }

        let captured = gear.requiredMeasurements.map { measurement in
            measurement.withValue(GearMeasurementValidation.parse(entries[measurement.id] ?? ""))
        }
        let savedGear = gear.withRequiredMeasurements(captured)

        isSaving = true
        defer { isSaving = false }
        do {
            try await favouriteGears.addFavourite(savedGear)
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
