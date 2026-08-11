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
/// the full in-progress record for eventual submission (e.g. a future "Check your answers" screen).
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
    /// The statistical (catch) area recorded for this trip.
    var statisticalArea: String?
    /// The gear used to make the catch, including its captured measurements.
    var gear: GearOption?
    /// Species caught and landed, with their captured weights.
    var speciesCaught: [SpeciesOption] = []
    /// Species caught but not landed (e.g. discarded).
    var speciesNotLanded: [SpeciesOption] = []

    /// `nonisolated` so `CatchRecordDraft()` can be used as a default parameter value from any
    /// isolation context (e.g. non-`@MainActor` `View` initializers) without a hop to the main
    /// actor; it only sets default property values, so this is safe.
    nonisolated init() {}
}
