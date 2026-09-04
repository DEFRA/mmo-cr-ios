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

    /// Loads favourite gears for display, then ticks and pre-fills every gear already confirmed for
    /// this trip (`draft.gearCatches` — see ADR-0011), so returning to this screen (e.g. via
    /// "Change" on a gear's variable measurements from Check your answers) shows every previously
    /// selected gear ticked with its own captured variable-measurement values ready to edit, rather
    /// than starting blank. Uses each `GearCatch`'s own captured `gear` (not the favourites list) as
    /// the source of the previously-entered values, since favourites do not carry per-trip variable
    /// measurements. Failures leave the list empty.
    func loadFavourites() async {
        favourites = (try? await favouriteGears.favouriteGears()) ?? []
        for gearCatch in draft.gearCatches {
            selection.insert(gearCatch.gear.id)
            for measurement in gearCatch.gear.variableMeasurements {
                guard let value = measurement.value else { continue }
                variableEntries[entryKey(gearID: gearCatch.gear.id, measurementID: measurement.id)] = String(value)
            }
        }
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
    /// measurements attached, into `draft.gearCatches` — one entry per gear (see ADR-0011). A gear
    /// that already has a `GearCatch` in the draft (e.g. re-ticked after "Add another gear", or
    /// edited via "Change" from Check your answers) keeps its already-captured statistical
    /// area/species caught rather than losing that progress; a newly-ticked gear starts a fresh,
    /// empty entry ready for the catch-location/species screens to fill in.
    ///
    /// Normally routes to the catch-location screen for the **first** confirmed gear, and the
    /// journey loops back here for each subsequent gear once its species screen is saved
    /// (`CatchRecordRouting.speciesCompletionRoute`). When reached via "Change" from Check your
    /// answers (`draft.returnToCheckYourAnswers`), returns straight there instead, skipping the
    /// catch-location/species screens (see ADR-0013).
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

        draft.gearCatches = confirmedGears.map { gear in
            if let existingIndex = draft.gearCatchIndex(forGearID: gear.id) {
                let existing = draft.gearCatches[existingIndex]
                return GearCatch(gear: gear, statisticalArea: existing.statisticalArea, speciesCaught: existing.speciesCaught)
            }
            return GearCatch(gear: gear)
        }

        if draft.returnToCheckYourAnswers {
            draft.returnToCheckYourAnswers = false
            router.push(.checkYourAnswers(referenceNumber: referenceNumber))
            return
        }

        router.push(.catchLocation(gear: firstGear, vessel: vessel, referenceNumber: referenceNumber))
    }

    /// Routes to the Add-gear search screen.
    func addAnotherGear() {
        router.push(.addGear(vessel: vessel, referenceNumber: referenceNumber))
    }
}
