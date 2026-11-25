import Foundation
import os

/// View model for the Select vessel screen.
///
/// Vessels come from an injected `VesselProviding` (real, synced API data in production — see
/// `SyncedVesselSearchProvider`, ADR-0024/ADR-0028) rather than a static list, so this screen must
/// explicitly load before it can offer anything to select.
@MainActor
@Observable
final class SelectVesselViewModel {

    /// What this screen currently shows: still loading, a list to choose from, or no vessels
    /// available at all (nothing downloaded yet — though Home itself already blocks on vessels
    /// being required data, see ADR-0024 — or a signed-in user with no vessels linked to their
    /// account). Never an indefinite spinner (accessibility.instructions.md).
    enum State: Equatable {
        case loading
        case loaded([VesselOption])
        case empty
    }

    /// Static, UI-only placeholder reference number shown when no RSS number is known for the
    /// selected vessel (`VesselOption.rssNumber` is `nil`), and reused by any screen still routing
    /// with a bare `referenceNumber:` string ahead of a resumed draft loading its own
    /// `catchRecordReference` (see ADR-0026). Not derived from any backend.
    static let placeholderReferenceNumber = "A1234520260727150815"

    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "catchRecord")

    private(set) var state: State = .loading
    var selectionID: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    /// Shared journey draft; the chosen vessel is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft
    private let provider: VesselProviding
    private let referenceGenerator: CatchRecordReferenceGenerator

    init(
        router: CatchRecordRouter,
        provider: VesselProviding = SyncedVesselSearchProvider(),
        draft: CatchRecordDraft = CatchRecordDraft(),
        referenceGenerator: CatchRecordReferenceGenerator = CatchRecordReferenceGenerator()
    ) {
        self.router = router
        self.draft = draft
        self.provider = provider
        self.referenceGenerator = referenceGenerator
        // Pre-fills the previously-captured vessel when restarting a resumed draft from the
        // beginning (see ADR-0015 decision #1), so the user is not asked to re-choose it. The
        // snapshot's stable id is preferred; `load()` falls back to matching by name for a draft
        // persisted before `vesselSnapshot` existed, once the real list has loaded.
        self.selectionID = draft.vesselSnapshot?.id
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectVesselValidation.errorKey(for: selectionID)
    }

    /// Loads the available vessels — called from `SelectVesselView`'s `.task`.
    func load() async {
        let vessels = await provider.vessels()
        if selectionID == nil, let vesselName = draft.vessel {
            selectionID = vessels.first { $0.name == vesselName }?.id
        }
        state = vessels.isEmpty ? .empty : .loaded(vessels)
    }

    /// Runs validation for "Save and continue" and, once valid, replaces this screen with the
    /// journey's next one.
    ///
    /// Vessel selection is a one-time, first step of the journey (see ADR-0013 amendment — the
    /// vessel cannot be changed once a record exists): there is no "Change" link to it from Check
    /// your answers, and `router.replaceCurrent(with:)` removes `.selectVessel` from the
    /// navigation stack as it commits, rather than pushing on top of it — so Back/the swipe-back
    /// gesture from the next screen leaves the journey (returning to Home) instead of re-opening
    /// vessel selection.
    ///
    /// Generates `draft.catchRecordReference` **once**, here, the moment the vessel is confirmed
    /// (ADR-0026) — a resumed draft (`draft.catchRecordReference != nil`) never regenerates it, so
    /// the reference is stable for the rest of this draft's life. If the selected vessel has no
    /// known RSS number (`VesselOption.rssNumber` is `nil`), or generation otherwise fails, falls
    /// back to `placeholderReferenceNumber` — a safe, visible degradation rather than blocking the
    /// journey — and logs a diagnostic (vessel name only, never any generated value, since the
    /// fallback string itself is a constant).
    func submit() {
        didAttemptSubmit = true
        guard case .loaded(let vessels) = state,
              let selectionID,
              let selected = vessels.first(where: { $0.id == selectionID }) else { return }
        draft.vessel = selected.name
        draft.vesselSnapshot = selected
        if draft.catchRecordReference == nil {
            draft.catchRecordReference = generateReference(for: selected)
        }
        let referenceNumber = draft.catchRecordReference ?? Self.placeholderReferenceNumber
        router.replaceCurrent(with: .tripStartedToday(vessel: selected.name, referenceNumber: referenceNumber))
    }

    private func generateReference(for vessel: VesselOption) -> String? {
        guard let rssNumber = vessel.rssNumber else {
            Self.logger.notice("No RSS number known for selected vessel; using placeholder reference")
            return nil
        }
        do {
            return try referenceGenerator.generate(rssNumber: rssNumber)
        } catch {
            Self.logger.error("Failed to generate catch record reference; using placeholder reference")
            return nil
        }
    }
}
