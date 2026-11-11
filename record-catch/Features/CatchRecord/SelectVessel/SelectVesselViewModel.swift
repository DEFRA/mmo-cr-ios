import Foundation
import os

/// View model for the Select vessel screen.
///
/// UI only — vessels come from an injected `VesselProviding` so a future API-backed provider can
/// swap in without changing this view model or its tests.
@MainActor
@Observable
final class SelectVesselViewModel {

    /// Static, UI-only placeholder reference number shown when no RSS number is known for the
    /// selected vessel (`VesselProviding.rssNumber(forVesselNamed:)` returns `nil`), and reused by
    /// any screen still routing with a bare `referenceNumber:` string ahead of a resumed draft
    /// loading its own `catchRecordReference` (see ADR-0026). Not derived from any backend.
    static let placeholderReferenceNumber = "A1234520260727150815"

    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "catchRecord")

    let vessels: [String]
    var selection: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    /// Shared journey draft; the chosen vessel is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft
    private let provider: VesselProviding
    private let referenceGenerator: CatchRecordReferenceGenerator

    init(
        router: CatchRecordRouter,
        provider: VesselProviding = StaticVesselProvider(),
        draft: CatchRecordDraft = CatchRecordDraft(),
        referenceGenerator: CatchRecordReferenceGenerator = CatchRecordReferenceGenerator()
    ) {
        self.router = router
        self.vessels = provider.vessels
        self.draft = draft
        self.provider = provider
        self.referenceGenerator = referenceGenerator
        // Pre-fills the previously-captured vessel when restarting a resumed draft from the
        // beginning (see ADR-0015 decision #1), so the user is not asked to re-choose it.
        self.selection = draft.vessel
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectVesselValidation.errorKey(for: selection)
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
    /// known RSS number (`VesselProviding.rssNumber(forVesselNamed:)` returns `nil`), or generation
    /// otherwise fails, falls back to `placeholderReferenceNumber` — a safe, visible degradation
    /// rather than blocking the journey — and logs a diagnostic (vessel name only, never any
    /// generated value, since the fallback string itself is a constant).
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }
        draft.vessel = selection
        if draft.catchRecordReference == nil {
            draft.catchRecordReference = generateReference(forVesselNamed: selection)
        }
        let referenceNumber = draft.catchRecordReference ?? Self.placeholderReferenceNumber
        router.replaceCurrent(with: .tripStartedToday(vessel: selection, referenceNumber: referenceNumber))
    }

    private func generateReference(forVesselNamed vesselName: String) -> String? {
        guard let rssNumber = provider.rssNumber(forVesselNamed: vesselName) else {
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
