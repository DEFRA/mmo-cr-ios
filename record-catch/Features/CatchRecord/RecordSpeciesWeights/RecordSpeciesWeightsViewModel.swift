import Foundation

/// View model for the "Which species did you catch with <gear>?" screen.
///
/// Loads the user's favourite species (offline-first, local source of truth — mirrors gears), lets
/// the user tick species and enter live weights (the "above minimum" field is always shown when a
/// species is ticked; "below minimum" and "legally discarded" are optional fields the user can
/// reveal and remove). On "Save and continue" the captured weights are written back to favourites
/// and the journey routes to the summary. "Add a species" pushes the Add-species search screen.
///
/// Validated on "Save and continue": at least one species must be ticked, and each ticked
/// species' mandatory "above minimum" weight must be present and match its `WeightPrecision`; the
/// optional "below minimum"/"legally discarded" fields are validated only when non-blank (see
/// `RecordSpeciesWeightsValidation`, `SpeciesWeightValidation`).
@MainActor
@Observable
final class RecordSpeciesWeightsViewModel {

    /// The gear these species were caught with — supplies the "with <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward for the Add-species header.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite species, loaded from the provider.
    private(set) var favourites: [SpeciesOption] = []
    /// The ids of the ticked species.
    var selection: Set<String> = []

    /// Per-species raw weight entries, keyed by species id.
    var aboveEntries: [String: String] = [:]
    var belowEntries: [String: String] = [:]
    var discardedEntries: [String: String] = [:]
    /// Species ids for which the optional "below minimum" / "legally discarded" fields are revealed.
    private(set) var belowRevealed: Set<String> = []
    private(set) var discardedRevealed: Set<String> = []

    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false
    /// Set once "Save and continue" has been attempted, so inline errors only appear after a
    /// submit (mirroring every other validated screen in the journey).
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the recorded species-caught list is written into it on submit (see
    /// `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
    }

    /// Loads favourite species and seeds the fields with **this gear's own** previously-captured
    /// species, if any (`draft.gearCatches[…].speciesCaught` — see ADR-0011), so returning to edit
    /// this same gear's catch (e.g. via "Change" from Check your answers) shows what was already
    /// recorded for it.
    ///
    /// Deliberately does **not** seed from the shared `FavouriteSpeciesProviding` store's own
    /// weights: that store is shared across every gear in the trip and `addFavourite` overwrites a
    /// species' weights by id regardless of which gear recorded them, so on a multi-gear journey it
    /// would carry the *previous* gear's weights onto this gear's screen. Each gear's catch starts
    /// blank until captured for that gear specifically. Failures leave the list empty.
    func loadFavourites() async {
        let loaded = (try? await favouriteSpecies.favouriteSpecies()) ?? []
        favourites = loaded

        let recordedForThisGear = draft.gearCatchIndex(forGearID: gear.id)
            .map { draft.gearCatches[$0].speciesCaught } ?? []
        let recordedByID = Dictionary(uniqueKeysWithValues: recordedForThisGear.map { ($0.id, $0) })

        for species in loaded {
            guard let recorded = recordedByID[species.id] else { continue }
            if !recorded.weightAboveMinimumKg.isEmpty
                || recorded.weightBelowMinimumKg != nil
                || recorded.weightLegallyDiscardedKg != nil {
                selection.insert(species.id)
            }
            aboveEntries[species.id] = recorded.weightAboveMinimumKg
            if let below = recorded.weightBelowMinimumKg {
                belowEntries[species.id] = below
                belowRevealed.insert(species.id)
            }
            if let discarded = recorded.weightLegallyDiscardedKg {
                discardedEntries[species.id] = discarded
                discardedRevealed.insert(species.id)
            }
        }
    }

    /// Whether a species is currently ticked.
    func isSelected(_ id: String) -> Bool { selection.contains(id) }    /// Toggles a species' ticked state.
    func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// Whether the optional "below minimum" field is revealed for a species.
    func isBelowRevealed(_ id: String) -> Bool { belowRevealed.contains(id) }
    /// Whether the optional "legally discarded" field is revealed for a species.
    func isDiscardedRevealed(_ id: String) -> Bool { discardedRevealed.contains(id) }

    func revealBelow(_ id: String) { belowRevealed.insert(id) }
    func removeBelow(_ id: String) {
        belowRevealed.remove(id)
        belowEntries[id] = nil
    }

    func revealDiscarded(_ id: String) { discardedRevealed.insert(id) }
    func removeDiscarded(_ id: String) {
        discardedRevealed.remove(id)
        discardedEntries[id] = nil
    }

    /// "Select at least one species" — shown once a submit has been attempted with nothing ticked.
    var selectionErrorMessage: ValidationMessage? {
        guard didAttemptSubmit else { return nil }
        return RecordSpeciesWeightsValidation.selectionErrorMessage(selection: selection)
    }

    /// Every weight-field error for the ticked species, once a submit has been attempted, keyed by
    /// `(speciesID, field)` so each `TextInputField` can render its own message.
    var weightErrorMessages: [SpeciesFieldKey: ValidationMessage] {
        guard didAttemptSubmit else { return [:] }
        return RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: selection,
            species: favourites,
            entries: SpeciesWeightEntries(
                above: aboveEntries,
                below: belowEntries,
                discarded: discardedEntries,
                belowRevealed: belowRevealed,
                discardedRevealed: discardedRevealed
            )
        )
    }

    /// Every validation message currently showing, in priority order (selection first, then each
    /// species' weight errors) — used to drive the "There is a problem" error summary.
    var allErrorMessages: [ValidationMessage] {
        var messages: [ValidationMessage] = []
        if let selectionErrorMessage { messages.append(selectionErrorMessage) }
        messages.append(contentsOf: weightErrorMessages.values)
        return messages
    }

    /// The route to push after saving. Pure and independent of async work, so it is directly
    /// unit-testable.
    ///
    /// See `CatchRecordRouting.speciesCompletionRoute(...)`: returns straight to Check your answers
    /// when this gear's catch was reached by "Change" from there; otherwise loops back to the
    /// catch-location screen for the next selected gear when more than one gear was chosen, or
    /// continues to the trip-level landing-storage question once every gear is done (see ADR-0011).
    var completionRoute: CatchRecordRoute {
        CatchRecordRouting.speciesCompletionRoute(
            currentGearID: gear.id,
            orderedGears: draft.orderedGears,
            vessel: vessel,
            referenceNumber: referenceNumber,
            resumingAtCheckYourAnswers: draft.returnToCheckYourAnswers
        )
    }

    /// Routes to the Add-species search screen, returning here afterwards.
    func addSpecies() {
        router.push(.addSpecies(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: .recordWeights,
            context: .addAnother
        ))
    }

    /// Whether this gear's catch already has at least one species saved to the draft
    /// (`draft.gearCatches[…].speciesCaught` — see ADR-0011). Gates the "Remove species" link:
    /// there is nothing to remove until a "Save and continue" has recorded something.
    var hasRecordedSpecies: Bool {
        !(draft.gearCatchIndex(forGearID: gear.id).map { draft.gearCatches[$0].speciesCaught } ?? []).isEmpty
    }

    /// Routes to the Remove-species screen for this gear's recorded catch.
    func removeSpecies() {
        router.push(.removeSpecies(gear: gear, vessel: vessel, referenceNumber: referenceNumber))
    }

    /// Builds a species with its captured weights from the current field state.
    private func capturedSpecies(_ species: SpeciesOption) -> SpeciesOption {
        species.withWeights(
            above: aboveEntries[species.id] ?? "",
            below: belowRevealed.contains(species.id) ? (belowEntries[species.id] ?? "") : nil,
            discarded: discardedRevealed.contains(species.id) ? (discardedEntries[species.id] ?? "") : nil
        )
    }

    /// Validates "Select at least one species" and each ticked species' weight fields before
    /// writing captured weights for ticked species back to favourites and into this gear's own
    /// `GearCatch` entry (`draft.gearCatches[…].speciesCaught` - see ADR-0011), then routing on.
    func submit() async {
        didAttemptSubmit = true
        saveFailed = false
        guard allErrorMessages.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            var captured: [SpeciesOption] = []
            for species in favourites where selection.contains(species.id) {
                let recorded = capturedSpecies(species)
                try await favouriteSpecies.addFavourite(recorded)
                captured.append(recorded)
            }
            if let index = draft.gearCatchIndex(forGearID: gear.id) {
                draft.gearCatches[index].speciesCaught = captured
            }
            let route = completionRoute
            draft.returnToCheckYourAnswers = false
            router.push(route)
        } catch {
            saveFailed = true
        }
    }
}
