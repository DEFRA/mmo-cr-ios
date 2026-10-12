import Foundation

/// View model for the late-submission nudge screen.
///
/// Shown directly before "Check your catch record" when the trip ended more than 24 hours ago
/// (see `SubmissionNudge`, `CatchRecordRouting.checkYourAnswersOrNudgeRoute`) — reached from the
/// landing-storage "No" answer, the species-not-landed screen, resuming a draft already at that
/// checkpoint, or a "Change" edit to the return date that still leaves the trip late. It is an
/// information-only screen: "Save and continue" proceeds straight to "Check your catch record";
/// "Check the trip end date" opens the return-date screen in "Change" mode so the date can be
/// corrected, after which the journey returns here (or straight to "Check your catch record" if
/// the correction resolves the lateness). UI only — no persistence or networking.
@MainActor
@Observable
final class SubmissionNudgeViewModel {

    /// Whole days the record is being submitted after the trip end date; drives the heading.
    let daysLate: Int
    /// Selected vessel name, threaded onward to the return-date screen if the date is corrected.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    private let router: CatchRecordRouter
    /// Shared journey draft; set when "Check the trip end date" is tapped, so the return-date
    /// screen knows to route back here (via `CatchRecordRouting.checkYourAnswersOrNudgeRoute`)
    /// rather than continuing into the port sub-journey (see ADR-0013's "Change always resumes"
    /// pattern).
    private let draft: CatchRecordDraft

    init(
        daysLate: Int,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.daysLate = daysLate
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
    }

    /// "Save and continue" — acknowledges the nudge and continues straight to "Check your catch
    /// record".
    func submit() {
        router.push(.checkYourAnswers(referenceNumber: referenceNumber))
    }

    /// "Check the trip end date" — opens the return-date screen in "Change" mode so the user can
    /// correct it; submitting there re-runs the late-submission check before returning here or to
    /// "Check your catch record" (see `TripDateViewModel.submit()`).
    func checkTripEndDate() {
        draft.returnToCheckYourAnswers = true
        router.push(.tripDate(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: draft.departureDate
        ))
    }
}
