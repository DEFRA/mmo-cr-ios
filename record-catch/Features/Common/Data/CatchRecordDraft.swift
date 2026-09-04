import Foundation

/// The single, journey-scoped, offline-first source of truth for the in-progress "Create a catch
/// record" journey.
///
/// Mirrors the favourites providers (`FavouritePortsProviding`, `FavouriteGearProviding`,
/// `FavouriteSpeciesProviding` — see ADR-0004): a single reference type shared across every screen
/// in the `NavigationStack` so data captured on one screen (e.g. the selected vessel, dates, ports,
/// gear, species) is visible to later screens in the same journey without re-fetching or
/// re-deriving it from route payloads. It **complements** rather than replaces the route-payload
/// approach in ADR-0003/ADR-0004: routes may still carry the specific values a destination needs
/// for its own display logic (e.g. deep-linking in UI tests), while `CatchRecordDraft` accumulates
/// the full in-progress record for eventual submission (e.g. the "Check your answers" screen).
///
/// `@Observable` so SwiftUI views reading its properties update automatically. `@MainActor` because
/// it is mutated directly from view models and views on the main actor — no background writes in
/// this phase.
///
/// Not persisted to disk in this phase. A future ADR covers on-device persistence (e.g. SwiftData)
/// and sync of the in-progress draft, so the journey can be resumed after the app is terminated.
@MainActor
@Observable
final class CatchRecordDraft {

    /// The vessel this catch record is for.
    var vessel: String?
    /// The date the trip departed.
    var departureDate: Date?
    /// The date the trip returned.
    var returnDate: Date?
    /// The port the vessel departed from.
    var departurePort: PortOption?
    /// The port the vessel returned to.
    var returnPort: PortOption?
    /// One entry per gear ticked on "What gear did you use?", in selection order. Each holds that
    /// gear's own statistical (sub)area and species caught — captured **per gear**, not once for
    /// the whole trip (see ADR-0011). Empty until gear selection completes.
    var gearCatches: [GearCatch] = []
    /// Species caught but not landed (e.g. discarded). A single, trip-level list — asked once,
    /// after every gear's catch has been recorded — unlike `gearCatches`, this is not split per
    /// gear (see ADR-0011).
    var speciesNotLanded: [SpeciesOption] = []
    /// Set by `CheckYourAnswersViewModel.change(to:resumingAtCheckYourAnswers:)` when a "Change"
    /// link for a gear's statistical area or species-caught is tapped from Check your answers, so
    /// that once its onward mini-journey (which may re-enter the catch-location and species
    /// screens for that one gear) completes, the journey returns straight back to Check your
    /// answers rather than continuing through any other selected gears (see ADR-0011). Reset
    /// whenever `change(to:)` is called again, and consumed by
    /// `RecordSpeciesWeightsViewModel.submit()`.
    var returnToCheckYourAnswersAfterSpecies = false

    /// `nonisolated` so `CatchRecordDraft()` can be used as a default parameter value from any
    /// isolation context (e.g. non-`@MainActor` `View` initializers) without a hop to the main
    /// actor; it only sets default property values, so this is safe.
    nonisolated init() {}

    /// The confirmed gears, in the order they were selected — convenience over
    /// `gearCatches.map(\.gear)`.
    var orderedGears: [GearOption] { gearCatches.map(\.gear) }

    /// The index of the `GearCatch` for a given gear id, if one has been recorded.
    func gearCatchIndex(forGearID gearID: String) -> Int? {
        gearCatches.firstIndex { $0.id == gearID }
    }
}
