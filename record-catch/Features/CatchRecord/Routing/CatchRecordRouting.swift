import Foundation

/// Pure, static routing decisions for the "Create a catch record" journey.
///
/// Kept out of the router/views so the entry-point rule is trivially unit-testable with no
/// `NavigationStack` host required.
enum CatchRecordRouting {

    /// Resolves the route to enter when a submissions-table date link is tapped.
    ///
    /// Only an **Unsent** (draft) row has a defined next step in this phase; every other status
    /// resolves to `nil` and stays inert, matching current Home behaviour.
    static func entryRoute(for row: SubmissionRow) -> CatchRecordRoute? {
        guard row.status == .unsent else { return nil }
        return .draftAction(row)
    }

    /// Resolves the route to enter the port sub-journey once the trip dates are known.
    ///
    /// - When the user already has favourite ports, go straight to the departure select screen.
    /// - Otherwise, go to the Add-port screen first (no originating select phase).
    ///
    /// The (async) favourites fetch is performed by the caller; this decision stays pure so it is
    /// trivially unit-testable (see ADR-0004).
    static func portEntryRoute(
        hasFavourites: Bool,
        vessel: String,
        referenceNumber: String
    ) -> CatchRecordRoute {
        hasFavourites
            ? .selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)
            : .addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)
    }

    /// Resolves the route to enter the gear sub-journey.
    ///
    /// - When the user already has favourite gears, show the select (checkbox) screen.
    /// - Otherwise, go straight to the Add-gear search screen.
    ///
    /// Pure so it is trivially unit-testable, mirroring `portEntryRoute`.
    static func gearEntryRoute(
        hasFavourites: Bool,
        vessel: String,
        referenceNumber: String
    ) -> CatchRecordRoute {
        hasFavourites
            ? .selectGear(vessel: vessel, referenceNumber: referenceNumber)
            : .addGear(vessel: vessel, referenceNumber: referenceNumber)
    }
}
