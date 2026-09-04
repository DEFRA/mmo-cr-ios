import Foundation

/// View model for the "What gear did you use?" screen.
///
/// Loads the user's favourite gears (offline-first, local source of truth — mirrors ports), lets
/// the user tick one or more, captures each ticked gear's per-trip **variable** measurements (e.g.
/// the number of times the gear was shot), validates the selection, and routes on. "Add another
/// gear" pushes the Add-gear search screen.
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
    /// Raw field text for per-trip variable measurements, keyed by `"<gearId>.<measurementId>"`.
    var variableEntries: [String: String] = [:]
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

    /// The dictionary key for a gear's variable-measurement field text.
    private func entryKey(gearID: String, measurementID: String) -> String {
        "\(gearID).\(measurementID)"
    }

    /// Current group-level inline error ("select at least one"), once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectGearValidation.errorKey(for: selection)
    }

    /// The inline error key for a single variable-measurement field, once a submit has been
    /// attempted. Only ticked gears are validated; unticked gears never show an error.
    func variableErrorKey(gearID: String, measurementID: String) -> String? {
        guard didAttemptSubmit, selection.contains(gearID) else { return nil }
        let raw = variableEntries[entryKey(gearID: gearID, measurementID: measurementID)] ?? ""
        return GearMeasurementValidation.errorKey(for: raw)
    }

    /// Whether every ticked gear's variable measurements parse to valid whole numbers.
    var selectedVariableMeasurementsAreValid: Bool {
        for gear in favourites where selection.contains(gear.id) {
            for measurement in gear.variableMeasurements {
                let raw = variableEntries[entryKey(gearID: gear.id, measurementID: measurement.id)] ?? ""
                if GearMeasurementValidation.parse(raw) == nil { return false }
            }
        }
        return true
    }

    /// Validates "Save and continue" and routes on when at least one gear is ticked and every ticked
    /// gear's variable measurements are valid whole numbers.
    ///
    /// Captures **every** ticked gear (in favourites order), each with its own captured variable
    /// measurements attached, into `draft.gearCatches` — one entry per gear, ready for the
    /// catch-location/species screens to fill in that gear's own statistical area and species
    /// caught (see ADR-0011). Routes to the catch-location screen for the **first** confirmed gear;
    /// the journey loops back here for each subsequent gear once its species screen is saved
    /// (`CatchRecordRouting.speciesCompletionRoute`).
    func submit() {
        didAttemptSubmit = true
        guard !selection.isEmpty, selectedVariableMeasurementsAreValid else { return }

        let confirmedGears: [GearOption] = favourites
            .filter { selection.contains($0.id) }
            .map { gear in
                let captured = gear.variableMeasurements.map { measurement in
                    let raw = variableEntries[entryKey(gearID: gear.id, measurementID: measurement.id)] ?? ""
                    return measurement.withValue(GearMeasurementValidation.parse(raw))
                }
                return gear.withVariableMeasurements(captured)
            }
        guard let firstGear = confirmedGears.first else { return }

        draft.gearCatches = confirmedGears.map { GearCatch(gear: $0) }
        router.push(.catchLocation(gear: firstGear, vessel: vessel, referenceNumber: referenceNumber))
    }

    /// Routes to the Add-gear search screen.
    func addAnotherGear() {
        router.push(.addGear(vessel: vessel, referenceNumber: referenceNumber))
    }
}
