import Foundation

/// The screens in the "Create a catch record" journey (Part 1).
///
/// A typed, homogeneous route enum backing `CatchRecordRouter.path` — see ADR-0003 for why this
/// is preferred over `NavigationPath` here (testability, homogeneity, open-endedness).
enum CatchRecordRoute: Hashable {
    /// What to do with an existing unsent (draft) record, entered from the Home table.
    case draftAction(SubmissionRow)
    /// Choose the vessel for a new trip.
    case selectVessel
    /// Whether the trip started and finished today; carries the display-only placeholder
    /// reference number shown at the top of the screen.
    case tripStartedToday(referenceNumber: String)
    /// Collect a trip date (departure or return) — reached from the "No" answer on
    /// `tripStartedToday`. Carries the display-only reference number and, for the return
    /// variant, the parsed departure date (so a future phase can validate return ≥ departure
    /// without redesigning the route; unused for validation in this UI-only phase).
    case tripDate(phase: TripDatePhase, referenceNumber: String, departureDate: Date?)
    /// Minimal placeholder for the next step in the journey (future phase).
    case placeholderNextStep
}
