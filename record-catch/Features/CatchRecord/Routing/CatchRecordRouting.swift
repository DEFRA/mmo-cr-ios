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

    /// Resolves the route to enter the species sub-journey once the catch location is known.
    ///
    /// - When the user already has favourite species, show the "Record species weights" screen.
    /// - Otherwise, go straight to the Add-species search screen (returning to the weights screen).
    ///
    /// Pure so it is trivially unit-testable, mirroring `gearEntryRoute`.
    static func speciesEntryRoute(
        hasFavourites: Bool,
        gear: GearOption,
        vessel: String,
        referenceNumber: String
    ) -> CatchRecordRoute {
        hasFavourites
            ? .recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
            : .addSpecies(gear: gear, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)
    }

    /// Resolves where "Save and continue" on the "Which species did you catch with `<gear>`?"
    /// screen goes next (see ADR-0011).
    ///
    /// - When editing a single gear's catch from Check your answers
    ///   (`resumingAtCheckYourAnswers`), always return straight to Check your answers rather than
    ///   continuing through any other selected gears.
    /// - Otherwise, when more selected gears remain after `currentGearID` (a multi-gear journey),
    ///   loop back to the catch-location (map) screen for the **next** gear.
    /// - Otherwise (a single selected gear, or this was the last of several), continue to the
    ///   trip-level landing-storage question exactly as before multi-gear support.
    ///
    /// Pure so it is trivially unit-testable, mirroring the other `CatchRecordRouting` decisions.
    static func speciesCompletionRoute(
        currentGearID: String,
        orderedGears: [GearOption],
        vessel: String,
        referenceNumber: String,
        resumingAtCheckYourAnswers: Bool
    ) -> CatchRecordRoute {
        guard !resumingAtCheckYourAnswers else {
            return .checkYourAnswers(referenceNumber: referenceNumber)
        }
        guard let currentIndex = orderedGears.firstIndex(where: { $0.id == currentGearID }) else {
            return .landingStorage(referenceNumber: referenceNumber)
        }
        let nextIndex = orderedGears.index(after: currentIndex)
        guard orderedGears.indices.contains(nextIndex) else {
            return .landingStorage(referenceNumber: referenceNumber)
        }
        return .catchLocation(gear: orderedGears[nextIndex], vessel: vessel, referenceNumber: referenceNumber)
    }
}
