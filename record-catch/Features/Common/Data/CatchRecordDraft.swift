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

    /// Stable local identity for this draft's persisted on-device record (see ADR-0014,
    /// `CatchRecordDraftStoring`). Generated once per journey; a resumed journey's draft keeps the
    /// `localID` of the persisted record it was loaded from, so saving continues to update the same
    /// row rather than creating a duplicate. `nonisolated(unsafe)` purely so the `nonisolated init`
    /// below can set it directly (mirroring the class's existing default-parameter-value pattern);
    /// every actual read/write happens on the main actor in practice, same as every other property.
    nonisolated(unsafe) var localID: UUID

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
    /// Set by `CheckYourAnswersViewModel.change(to:)` whenever **any** "Change" link is tapped
    /// from Check your answers, so that once that link's own mini-journey (which may be a single
    /// screen, or a short chain such as the catch-location→species pair for a per-gear field)
    /// completes, the journey returns straight back to Check your answers rather than continuing
    /// forward through the rest of the create-a-catch-record journey (see ADR-0011, generalised to
    /// every field by ADR-0013). Consumed and reset by whichever screen's `submit()` is reached
    /// once that mini-journey completes.
    var returnToCheckYourAnswers = false
    /// The furthest section of the journey this draft has completed, persisted alongside every
    /// other field so resuming a draft can jump straight past what's already done (see ADR-0014
    /// decision #5, amended). Only ever moves forward — see `advance(to:)`.
    var checkpoint: CatchRecordCheckpoint = .vessel

    /// `nonisolated` so `CatchRecordDraft()` can be used as a default parameter value from any
    /// isolation context (e.g. non-`@MainActor` `View` initializers) without a hop to the main
    /// actor; it only sets default property values, so this is safe.
    nonisolated init(localID: UUID = UUID()) {
        self.localID = localID
    }

    /// The confirmed gears, in the order they were selected — convenience over
    /// `gearCatches.map(\.gear)`.
    var orderedGears: [GearOption] { gearCatches.map(\.gear) }

    /// The index of the `GearCatch` for a given gear id, if one has been recorded.
    func gearCatchIndex(forGearID gearID: String) -> Int? {
        gearCatches.firstIndex { $0.id == gearID }
    }

    /// Moves `checkpoint` forward to `newCheckpoint`, if it represents further progress than what
    /// is already recorded. Never moves it backwards, so a "Change" link revisiting an earlier
    /// screen (ADR-0013) cannot regress how far a resumed draft jumps forward to.
    func advance(to newCheckpoint: CatchRecordCheckpoint) {
        guard newCheckpoint > checkpoint else { return }
        checkpoint = newCheckpoint
    }

    /// A `Codable` snapshot of every persisted field, suitable for writing to
    /// `CatchRecordDraftStoring` (see ADR-0014). Deliberately excludes `localID` (carried
    /// separately by the store) and `returnToCheckYourAnswers` (a transient, in-memory navigation
    /// hint with no persisted meaning).
    var payload: CatchRecordDraftPayload {
        CatchRecordDraftPayload(
            vessel: vessel,
            departureDate: departureDate,
            returnDate: returnDate,
            departurePort: departurePort,
            returnPort: returnPort,
            gearCatches: gearCatches,
            speciesNotLanded: speciesNotLanded,
            checkpoint: checkpoint
        )
    }

    /// Overwrites every persisted field from a previously-saved payload (e.g. when resuming a
    /// draft from Home — see `DraftActionViewModel`). Mutates this instance in place, rather than
    /// replacing it, so every screen already holding a reference to the shared draft (via
    /// `.environment(draft)`) observes the resumed values.
    func apply(_ payload: CatchRecordDraftPayload) {
        vessel = payload.vessel
        departureDate = payload.departureDate
        returnDate = payload.returnDate
        departurePort = payload.departurePort
        returnPort = payload.returnPort
        gearCatches = payload.gearCatches
        speciesNotLanded = payload.speciesNotLanded
        checkpoint = payload.checkpoint
    }
}

/// The furthest section of the "Create a catch record" journey a draft has completed, used to
/// resume it at (roughly) the right screen instead of always restarting from `.selectVessel` (see
/// `CatchRecordDraft.checkpoint`, ADR-0014 decision #5).
///
/// Deliberately coarse — one case per major section, not one per `CatchRecordRoute` case — so only
/// a handful of existing "section boundary" view models need a single additive
/// `draft.advance(to:)` call, and resuming stays a small, pure mapping back onto the existing
/// `CatchRecordRouting` entry-point helpers rather than replaying the exact route stack.
/// `Int`-backed and `Comparable` so `advance(to:)` can enforce "never move backwards".
nonisolated enum CatchRecordCheckpoint: Int, Codable, Comparable, Sendable {
    /// Nothing beyond the vessel (or nothing at all) has been captured yet.
    case vessel = 0
    /// The trip-started-today/trip-date sub-journey (and the late-submission nudge, if shown) has
    /// been resolved.
    case tripDates = 1
    /// Both the departure and return ports have been resolved.
    case ports = 2
    /// Every selected gear's catch (statistical area + species) has been recorded.
    case gear = 3
    /// The "any catch not landed straight away?" question has been answered.
    case landingStorage = 4
    /// Check your answers has been reached at least once.
    case checkYourAnswers = 5

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A `Codable` snapshot of every field `CatchRecordDraft` accumulates across the journey, used as
/// the on-disk representation stored by `CatchRecordDraftStoring` (see ADR-0014). Kept as a plain
/// value type, separate from the `@Observable` reference-typed `CatchRecordDraft`, so encoding/
/// decoding has no `@MainActor` isolation requirement of its own.
nonisolated struct CatchRecordDraftPayload: Codable, Equatable, Sendable {
    var vessel: String?
    var departureDate: Date?
    var returnDate: Date?
    var departurePort: PortOption?
    var returnPort: PortOption?
    var gearCatches: [GearCatch]
    var speciesNotLanded: [SpeciesOption]
    /// See `CatchRecordDraft.checkpoint`. Added after the first release of this payload shape. The
    /// default here is what the synthesized memberwise initializer (see below) falls back to, and
    /// `init(from:)` below applies the same fallback when decoding any already-persisted draft with
    /// no `checkpoint` key, rather than failing to decode the whole draft.
    var checkpoint: CatchRecordCheckpoint = .vessel
}

/// `init(from:)` is deliberately declared here, in an **extension**, rather than in the primary
/// declaration above: a struct's synthesized memberwise initializer is only suppressed by
/// initializers declared in its *primary* declaration, not by ones in an extension. Keeping the
/// custom decoding logic here means `CatchRecordDraftPayload` still gets its normal, fully-labelled
/// memberwise initializer (matching the property list above, in order, with `checkpoint`
/// defaulting to `.vessel`) for free — used by `CatchRecordDraft.payload` and in tests — instead of
/// a second, hand-maintained 8-parameter initializer that duplicates it and drifts if a field is
/// ever added or removed.
extension CatchRecordDraftPayload {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vessel = try container.decodeIfPresent(String.self, forKey: .vessel)
        departureDate = try container.decodeIfPresent(Date.self, forKey: .departureDate)
        returnDate = try container.decodeIfPresent(Date.self, forKey: .returnDate)
        departurePort = try container.decodeIfPresent(PortOption.self, forKey: .departurePort)
        returnPort = try container.decodeIfPresent(PortOption.self, forKey: .returnPort)
        gearCatches = try container.decodeIfPresent([GearCatch].self, forKey: .gearCatches) ?? []
        speciesNotLanded = try container.decodeIfPresent([SpeciesOption].self, forKey: .speciesNotLanded) ?? []
        checkpoint = try container.decodeIfPresent(CatchRecordCheckpoint.self, forKey: .checkpoint) ?? .vessel
    }
}
