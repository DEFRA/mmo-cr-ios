import Foundation

/// The screens in the "Create a catch record" journey (Part 1).
///
/// A typed, homogeneous route enum backing `CatchRecordRouter.path` — see ADR-0003 for why this
/// is preferred over `NavigationPath` here (testability, homogeneity, open-endedness).
///
enum CatchRecordRoute: Hashable {
    /// What to do with an existing unsent (draft) record, entered from the Home table.
    case draftAction(SubmissionRow)
    /// Choose the vessel for a new trip.
    case selectVessel
    /// Whether the trip started and finished today; carries the selected vessel name (shown on
    /// later port screens) and the display-only placeholder reference number.
    case tripStartedToday(vessel: String, referenceNumber: String)
    /// Collect a trip date (departure or return) — reached from the "No" answer on
    /// `tripStartedToday`. Carries the selected vessel name, the display-only reference number
    /// and, for the return variant, the parsed departure date (so a future phase can validate
    /// return ≥ departure without redesigning the route; unused for validation in this UI-only
    /// phase).
    case tripDate(phase: TripDatePhase, vessel: String, referenceNumber: String, departureDate: Date?)
    /// Add a port via type-to-search and save it to the user's favourites (see ADR-0004). Shown
    /// when the user has no favourite ports yet, and reached from a select screen's "Add another
    /// port" button. `returnPhase` records which select screen to return to after saving
    /// (`nil` = first-time entry, which proceeds to the departure select screen).
    case addPort(vessel: String, referenceNumber: String, returnPhase: SelectPortPhase?)
    /// Pick a port (departure or return) from the user's favourite ports.
    case selectPort(phase: SelectPortPhase, vessel: String, referenceNumber: String)
    /// Choose the gear(s) used, from the user's favourite gears (multi-select checkboxes). Shown
    /// when the user already has favourite gears; "Add another gear" pushes `addGear`.
    case selectGear(vessel: String, referenceNumber: String)
    /// Add a gear via type-to-search. Shown when the user has no favourite gears yet, and reached
    /// from the select screen's "Add another gear" button.
    case addGear(vessel: String, referenceNumber: String)
    /// Enter the measurements for a chosen gear (e.g. mesh size for seine nets), then save it to
    /// favourites and return to the select screen.
    case gearMeasurements(gear: GearOption, vessel: String, referenceNumber: String)
    /// Pick the statistical area where most of the catch was caught using a given gear, from a map.
    /// Carries the gear (for the "using <gear>" heading), the vessel and the display-only reference
    /// number, all threaded onward unchanged.
    case catchLocation(gear: GearOption, vessel: String, referenceNumber: String)
    /// Minimal placeholder for the next step in the journey (future phase).
    case placeholderNextStep
}
