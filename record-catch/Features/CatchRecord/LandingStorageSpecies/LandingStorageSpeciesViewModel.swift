import Foundation

/// View model for the "Which species from this trip are you not landing straight away?" screen.
///
/// Reached from the "Yes" answer on the landing-storage question. Loads the user's favourite
/// species (offline-first, local source of truth — mirrors `RecordSpeciesWeightsViewModel`), lets
/// the user tick species that are being kept onboard/in keep pots, and records a single weight for
/// each ticked species ("weight above minimum size kept onboard or in keep pots"). On
/// "Save and continue" the captured weights are written back to favourites and the journey routes
/// to Check your answers.
///
/// Validated on "Save and continue": each ticked species' weight is mandatory and must match its
/// `WeightPrecision` (see `SpeciesWeightValidation`) — mirrors the record-weights screen's
/// "above minimum" field (plan Q2).
@MainActor
@Observable
final class LandingStorageSpeciesViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite species, loaded from the provider.
    private(set) var favourites: [SpeciesOption] = []
    /// The ids of the ticked species.
    var selection: Set<String> = []
    /// Per-species raw weight entries, keyed by species id.
    var weightEntries: [String: String] = [:]

    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false
    /// Set once "Save and continue" has been attempted, so inline errors only appear after a submit.
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the ticked species-not-landed list is written into it on submit (see
    /// `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
    }

    /// Loads favourite species and seeds the field with **this screen's own** previously-captured
    /// weights, if any (`draft.speciesNotLanded` — see ADR-0011), so returning to edit this answer
    /// (e.g. via "Change" from Check your answers) shows what was already recorded here.
    ///
    /// Deliberately does **not** seed from the shared `FavouriteSpeciesProviding` store's own
    /// weights: that store is shared with every per-gear catch screen and `addFavourite` overwrites
    /// a species' weights by id regardless of which screen recorded them, so it would show
    /// whichever gear's catch weight was saved most recently instead of this trip-level,
    /// not-landed weight, which is a distinct value. Failures leave the list empty.
    func loadFavourites() async {
        let loaded = (try? await favouriteSpecies.favouriteSpecies()) ?? []
        favourites = loaded

        let recordedByID = Dictionary(uniqueKeysWithValues: draft.speciesNotLanded.map { ($0.id, $0) })
        for species in loaded {
            guard let recorded = recordedByID[species.id], !recorded.weightAboveMinimumKg.isEmpty else { continue }
            selection.insert(species.id)
            weightEntries[species.id] = recorded.weightAboveMinimumKg
        }
    }

    /// Whether a species is currently ticked.
    func isSelected(_ id: String) -> Bool { selection.contains(id) }

    /// Toggles a species' ticked state.
    func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// The route to push after saving. Pure, so it is directly unit-testable.
    var completionRoute: CatchRecordRoute { .checkYourAnswers(referenceNumber: referenceNumber) }

    /// Every weight-field error for the ticked species, once a submit has been attempted, keyed by
    /// species id.
    var weightErrorMessages: [String: ValidationMessage] {
        guard didAttemptSubmit else { return [:] }
        var errors: [String: ValidationMessage] = [:]
        for species in favourites where selection.contains(species.id) {
            if let message = SpeciesWeightValidation.requiredErrorMessage(
                for: weightEntries[species.id] ?? "",
                speciesName: species.name,
                precision: species.weightPrecision,
                enterKey: "catchRecord.landingStorageSpecies.weight.validation.enter"
            ) {
                errors[species.id] = message
            }
        }
        return errors
    }

    /// Every validation message currently showing, in priority order — used to drive the "There
    /// is a problem" error summary. Ticking at least one species is not itself mandatory on this
    /// screen (it is only reached after answering "Yes" to "any catch not landed straight away?"),
    /// so only per-species weight errors are aggregated here.
    var allErrorMessages: [ValidationMessage] {
        Array(weightErrorMessages.values)
    }

    /// Writes captured weights for ticked species back to favourites, then routes onward, once
    /// every ticked species' weight is valid.
    func submit() async {
        didAttemptSubmit = true
        saveFailed = false
        guard weightErrorMessages.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            var kept: [SpeciesOption] = []
            for species in favourites where selection.contains(species.id) {
                let captured = species.withWeights(
                    above: weightEntries[species.id] ?? "",
                    below: nil,
                    discarded: nil
                )
                try await favouriteSpecies.addFavourite(captured)
                kept.append(captured)
            }
            draft.speciesNotLanded = kept
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
