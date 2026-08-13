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
    /// Warn that the record is being submitted more than 24 hours after the trip end date, so the
    /// user can double-check the date before continuing (see `SubmissionNudge`). Reached from a
    /// valid trip-return date that is more than 24 hours in the past. Carries the whole number of
    /// days late (for the heading), the vessel and the display-only reference number, all threaded
    /// onward into the port sub-journey when the user continues.
    case submissionNudge(daysLate: Int, vessel: String, referenceNumber: String)
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
    /// Record the species caught and their live weights, from the user's favourite species
    /// (per-species checkboxes with reveal-able weight fields). Shown when the user already has
    /// favourite species; "Add a species" pushes `addSpecies`, "Save and continue" pushes
    /// `speciesSummary`. Carries the gear (for the "with <gear>" heading), vessel and reference.
    case recordSpeciesWeights(gear: GearOption, vessel: String, referenceNumber: String)
    /// Add a species via type-to-search and save it to the user's favourites (see ADR-0004). Shown
    /// when the user has no favourite species yet, and reached from "Add a species"/"Add another
    /// species". `returnPhase` records which screen to return to after saving.
    case addSpecies(gear: GearOption, vessel: String, referenceNumber: String, returnPhase: SpeciesReturnPhase)
    /// Review the recorded species and their weights, with per-species removal, before continuing.
    case speciesSummary(gear: GearOption, vessel: String, referenceNumber: String)
    /// Ask whether any catch from this trip will not be landed straight away (e.g. bait or keep
    /// pots). A Yes/No radio question reached after the species summary; carries the display-only
    /// reference number shown at the top of the screen.
    case landingStorage(referenceNumber: String)
    /// Ask which species from this trip are *not* being landed straight away, and the weight of
    /// each kept onboard or in keep pots. Reached from the "Yes" answer on `landingStorage`;
    /// carries the display-only reference number shown at the top of the screen.
    case landingStorageSpecies(referenceNumber: String)
    /// Review every answer captured so far before submission. Reached at the end of the
    /// landing-storage sub-journey; carries the display-only reference number shown at the top of
    /// the screen.
    case checkYourAnswers(referenceNumber: String)
    /// Final confirmation before submitting a completed catch record. Reached from "Save and
    /// continue" on Check your answers; requires an explicit checkbox confirmation before
    /// "Accept and submit trip details" proceeds, which then calls the (stubbed)
    /// `CatchRecordSubmissionServicing` and, on success, pushes `submissionSuccess`. Carries the
    /// display-only reference number shown at the top of the screen.
    case submissionConfirmation(referenceNumber: String)
    /// The final "Your catch record has been submitted" screen, reached once the (stubbed)
    /// submission API call succeeds. Carries the reference number so it can be shown in the
    /// green confirmation panel; "View your catch records" returns to Home (`popToRoot()`).
    case submissionSuccess(referenceNumber: String)
}

/// Which species screen the Add-species screen should return to after a successful save.
///
/// Mirrors the port `returnPhase` pattern: first-time entry (no favourites yet) returns to the
/// weights screen; "Add another species" from the summary returns to the summary.
enum SpeciesReturnPhase: Hashable {
    /// Return to the "Record species weights" screen (first-time entry).
    case recordWeights
    /// Return to the "Species summary" screen ("Add another species").
    case summary
}
