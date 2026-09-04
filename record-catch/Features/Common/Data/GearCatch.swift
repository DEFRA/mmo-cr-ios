import Foundation

/// One selected gear's catch details for the "Create a catch record" journey.
///
/// Groups together the confirmed gear (with its captured required + variable measurements), the
/// statistical (sub)area where most of the catch using that gear was made, and the species caught
/// (with weights) using that gear. Introduced so `CatchRecordDraft` can hold **one of these per
/// selected gear** instead of a single flat `gear`/`statisticalArea`/`speciesCaught` — the
/// subrectangle and species caught are captured **per gear**, not once for the whole trip (see
/// ADR-0011). Species *not* landed remains a separate, trip-level list on `CatchRecordDraft`
/// (unchanged — it is asked once, after every gear's catch has been recorded).
///
/// `nonisolated` and `Sendable` to mirror `GearOption`/`SpeciesOption`, since it is built and read
/// from view models on the main actor but has no isolation needs of its own.
nonisolated struct GearCatch: Identifiable, Hashable, Sendable {
    /// The confirmed gear, including any captured required (per-favourite) and variable (per-trip)
    /// measurements. `var` so a later edit to this gear's measurements (e.g. via "Change" on Check
    /// your answers) can update it in place without disturbing the already-captured
    /// `statisticalArea`/`speciesCaught` for this same gear (see ADR-0013).
    var gear: GearOption
    /// The statistical (sub)area picked on the map (or entered manually) for this gear's catch,
    /// `nil` until captured.
    var statisticalArea: String?
    /// Species caught (and landed) using this gear, with their captured weights.
    var speciesCaught: [SpeciesOption]

    /// Stable identity mirrors the gear's — a gear can only appear once per draft (see
    /// `CatchRecordDraft.gearCatchIndex(forGearID:)`).
    var id: String { gear.id }

    init(gear: GearOption, statisticalArea: String? = nil, speciesCaught: [SpeciesOption] = []) {
        self.gear = gear
        self.statisticalArea = statisticalArea
        self.speciesCaught = speciesCaught
    }
}
