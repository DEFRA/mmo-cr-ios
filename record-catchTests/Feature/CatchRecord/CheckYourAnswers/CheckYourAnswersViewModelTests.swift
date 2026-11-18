import XCTest
@testable import record_catch

/// Deterministic, configurable `CatchRecordSubmissionQueuing` test double. Records every
/// `enqueue`/`submitNow` call so tests can assert on them, and lets the outcome of `submitNow` be
/// configured per test (including changed between calls, to exercise a retry-after-failure flow).
@MainActor
private final class MockCatchRecordSubmissionQueue: CatchRecordSubmissionQueuing {
    var submitNowOutcome: CatchRecordSubmissionOutcome = .submitted
    private(set) var enqueuedLocalIDs: [UUID] = []
    private(set) var submitNowCallCount = 0
    /// Simulates a slow in-flight send so `test_submit_whileAlreadySubmitting_...` can observe two
    /// overlapping `submit()` calls without a real network delay.
    var submitNowDelayNanoseconds: UInt64 = 0

    func enqueue(_ draft: CatchRecordDraft) async {
        enqueuedLocalIDs.append(draft.localID)
    }

    func submitNow(localID: UUID, timeout: TimeInterval) async -> CatchRecordSubmissionOutcome {
        submitNowCallCount += 1
        if submitNowDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: submitNowDelayNanoseconds)
        }
        return submitNowOutcome
    }

    func flushPending() async {}
}

@MainActor
final class CheckYourAnswersViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    private var seineNets: GearOption {
        GearOption.seineNets
            .withRequiredMeasurements([
                GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
            ])
            .withVariableMeasurements([
                GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
            ])
    }

    private func populatedDraft() -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.departureDate = Date(timeIntervalSince1970: 1_785_000_000)
        draft.returnDate = Date(timeIntervalSince1970: 1_785_100_000)
        draft.departurePort = PortOption(name: "Plymouth")
        draft.returnPort = PortOption(name: "Newlyn")
        draft.gearCatches = [
            GearCatch(
                gear: seineNets,
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
            )
        ]
        draft.speciesNotLanded = [
            SpeciesOption(name: "Hake (HKE)").withWeights(above: "5", below: nil, discarded: nil)
        ]
        return draft
    }

    /// A draft with two selected gears, each with their own area and species, for multi-gear
    /// section coverage (see ADR-0011).
    private func multiGearDraft() -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        let trawl = GearOption(name: "Trawl nets")
        draft.gearCatches = [
            GearCatch(
                gear: seineNets,
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
            ),
            GearCatch(
                gear: trawl,
                statisticalArea: "27.7.f",
                speciesCaught: [SpeciesOption(name: "Hake (HKE)").withWeights(above: "12", below: nil, discarded: nil)]
            )
        ]
        return draft
    }

    // MARK: - Section order

    func test_sections_withFullyPopulatedDraft_areOrderedTripGearSpeciesNotLanded() {
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        XCTAssertEqual(sut.sections.map(\.id), ["trip", "gear.\(seineNets.id)", "speciesNotLanded"])
    }

    func test_sections_withMultipleGears_hasOneSectionPerGear_inSelectionOrder() {
        let draft = multiGearDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        XCTAssertEqual(sut.sections.map(\.id), ["trip", "gear.\(seineNets.id)", "gear.Trawl nets"])
    }

    func test_sections_withEmptyDraft_omitsGearAndSpeciesSections_butAlwaysShowsTrip() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: CatchRecordDraft())

        XCTAssertEqual(sut.sections.map(\.id), ["trip"])
    }

    // MARK: - Trip section

    func test_tripSection_vesselRow_hasNoChangeRoute() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let row = sut.sections[0].rows.first { $0.id == "trip.vessel" }
        XCTAssertEqual(row?.value, "ACHILLES")
        // Vessel selection is a one-time step and cannot be changed once a record exists (see
        // ADR-0013 amendment), so this row has no "Change" link at all.
        XCTAssertNil(row?.changeRoute)
    }

    func test_tripSection_showsFormattedDepartureDateRow_routingToTripDateDeparturePhase() {
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let row = sut.sections[0].rows.first { $0.id == "trip.departureDate" }
        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .long
        expectedFormatter.timeStyle = .none
        XCTAssertEqual(row?.value, expectedFormatter.string(from: draft.departureDate!))
        XCTAssertEqual(
            row?.changeRoute,
            .tripDate(phase: .departure, vessel: "ACHILLES", referenceNumber: referenceNumber, departureDate: draft.departureDate)
        )
    }

    func test_tripSection_showsFormattedReturnDateRow_routingToTripDateReturnPhase() {
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let row = sut.sections[0].rows.first { $0.id == "trip.returnDate" }
        XCTAssertNotNil(row)
        XCTAssertEqual(
            row?.changeRoute,
            .tripDate(phase: .return, vessel: "ACHILLES", referenceNumber: referenceNumber, departureDate: draft.departureDate)
        )
    }

    // Regression test: when a trip started and finished on the same day (e.g. from
    // `TripStartedTodayViewModel`'s "Yes" path), `departureDate` and `returnDate` are equal —
    // both rows must still be shown, not just one of them.
    func test_tripSection_withSameDayDepartureAndReturnDate_showsBothDateRows() {
        let draft = populatedDraft()
        let sameDay = Date(timeIntervalSince1970: 1_785_000_000)
        draft.departureDate = sameDay
        draft.returnDate = sameDay
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let departureRow = sut.sections[0].rows.first { $0.id == "trip.departureDate" }
        let returnRow = sut.sections[0].rows.first { $0.id == "trip.returnDate" }

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .long
        expectedFormatter.timeStyle = .none
        let expectedValue = expectedFormatter.string(from: sameDay)

        XCTAssertEqual(departureRow?.value, expectedValue)
        XCTAssertEqual(returnRow?.value, expectedValue)
    }

    func test_tripSection_showsDeparturePortRow_routingToSelectPortDeparturePhase() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let row = sut.sections[0].rows.first { $0.id == "trip.departurePort" }
        XCTAssertEqual(row?.value, "Plymouth")
        XCTAssertEqual(row?.changeRoute, .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: referenceNumber))
    }

    func test_tripSection_showsReturnPortRow_routingToSelectPortReturnPhase() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let row = sut.sections[0].rows.first { $0.id == "trip.returnPort" }
        XCTAssertEqual(row?.value, "Newlyn")
        XCTAssertEqual(row?.changeRoute, .selectPort(phase: .return, vessel: "ACHILLES", referenceNumber: referenceNumber))
    }

    func test_tripSection_withEmptyDraft_hasNoRows() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: CatchRecordDraft())

        XCTAssertTrue(sut.sections[0].rows.isEmpty)
    }

    // MARK: - Per-gear section

    func test_gearSection_isTitledByGearName() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let section = sut.sections.first { $0.id == "gear.\(seineNets.id)" }
        XCTAssertNil(section?.titleKey)
        XCTAssertEqual(section?.literalTitle, seineNets.name)
    }

    func test_gearSection_showsGearNameAndMeshSize_routingToGearMeasurements() {
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let gearRows = sut.sections[1].rows
        let expectedRoute = CatchRecordRoute.gearMeasurements(gear: seineNets, vessel: "ACHILLES", referenceNumber: referenceNumber)

        let nameRow = gearRows.first { $0.id == "gear.\(seineNets.id).name" }
        XCTAssertEqual(nameRow?.value, seineNets.name)
        XCTAssertEqual(nameRow?.changeRoute, expectedRoute)

        let meshRow = gearRows.first { $0.id == "gear.\(seineNets.id).measurement.meshSize" }
        XCTAssertEqual(meshRow?.value, "80")
        XCTAssertEqual(meshRow?.changeRoute, expectedRoute)

        // Variable (per-trip) measurements are captured on the select-gear screen, so their
        // "Change" returns there rather than to the gear-measurements screen.
        let selectGearRoute = CatchRecordRoute.selectGear(vessel: "ACHILLES", referenceNumber: referenceNumber)
        let timesShotRow = gearRows.first { $0.id == "gear.\(seineNets.id).variableMeasurement.timesShot" }
        XCTAssertEqual(timesShotRow?.value, "5")
        XCTAssertEqual(timesShotRow?.changeRoute, selectGearRoute)
    }

    func test_gearSection_showsStatisticalAreaRow_routingToCatchLocation_andResumingAtCheckYourAnswers() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let row = sut.sections[1].rows.first { $0.id == "gear.\(seineNets.id).statisticalArea" }
        XCTAssertEqual(row?.value, "27.7.e")
        XCTAssertEqual(row?.changeRoute, .catchLocation(gear: seineNets, vessel: "ACHILLES", referenceNumber: referenceNumber))
        XCTAssertEqual(row?.gearName, seineNets.name)
    }

    func test_gearSection_showsSpeciesCaughtRows_routingToRecordSpeciesWeights_andResumingAtCheckYourAnswers() {
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let expectedRoute = CatchRecordRoute.recordSpeciesWeights(gear: seineNets, vessel: "ACHILLES", referenceNumber: referenceNumber)
        let speciesRows = sut.sections[1].rows.filter { $0.id.contains("speciesCaught") }
        XCTAssertEqual(speciesRows.map(\.value), ["Atlantic cod (COD)", "250 kg"])
        XCTAssertTrue(speciesRows.allSatisfy { $0.changeRoute == expectedRoute })
        XCTAssertTrue(speciesRows.allSatisfy { $0.gearName == seineNets.name })
    }

    func test_gearSection_withNoStatisticalAreaOrSpeciesYet_showsOnlyGearRows() {
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft)

        let rows = sut.sections[1].rows
        XCTAssertEqual(rows.map(\.id), ["gear.\(GearOption.seineNets.id).name"])
    }

    // MARK: - Species not landed section

    func test_speciesNotLandedSection_showsOneRowSetPerSpecies_routingToLandingStorageSpecies() {
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: populatedDraft())

        let section = sut.sections.first { $0.id == "speciesNotLanded" }
        XCTAssertEqual(section?.rows.map(\.value), ["Hake (HKE)", "5 kg"])
        let expectedRoute = CatchRecordRoute.landingStorageSpecies(referenceNumber: referenceNumber)
        XCTAssertTrue(section?.rows.allSatisfy { $0.changeRoute == expectedRoute } ?? false)
    }

    // MARK: - Change navigation

    func test_change_pushesGivenRouteOntoRouter() {
        let router = CatchRecordRouter()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: populatedDraft())

        sut.change(to: .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: referenceNumber))

        XCTAssertEqual(router.path, [.selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: referenceNumber)])
    }

    func test_change_alwaysSetsReturnToCheckYourAnswersDraftFlag() {
        let router = CatchRecordRouter()
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: draft)

        sut.change(to: .catchLocation(gear: seineNets, vessel: "ACHILLES", referenceNumber: referenceNumber))

        XCTAssertTrue(draft.returnToCheckYourAnswers)
    }

    func test_change_forATripLevelRoute_alsoSetsReturnToCheckYourAnswersDraftFlag() {
        let router = CatchRecordRouter()
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: draft)

        sut.change(to: .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: referenceNumber))

        XCTAssertTrue(draft.returnToCheckYourAnswers)
    }

    // MARK: - Submit (ADR-0028 — the submission queue)

    func test_submit_whenOnline_andQueueSubmitsSuccessfully_pushesSubmissionSuccess_andEnqueuesFirst() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowOutcome = .submitted
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: draft, submissionQueue: queue)

        await sut.submit()

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
        XCTAssertEqual(queue.enqueuedLocalIDs, [draft.localID], "the record must always be enqueued before any send attempt")
        XCTAssertEqual(queue.submitNowCallCount, 1)
    }

    // MARK: - Submission queued / retryable failure (error-handling path — 100% coverage requirement)

    func test_submit_whenOnline_butQueueOutcomeIsStillQueued_routesToSubmissionSaved_notSuccess() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowOutcome = .queued

        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: populatedDraft(), submissionQueue: queue)
        await sut.submit()

        XCTAssertEqual(router.path, [.submissionSaved(referenceNumber: referenceNumber)])
        XCTAssertFalse(sut.submitFailed)
    }

    func test_submit_whenSubmissionFailsPermanently_setsSubmitFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowOutcome = .failedPermanently

        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: populatedDraft(), submissionQueue: queue)
        await sut.submit()

        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_retryAfterPermanentFailure_clearsSubmitFailed_andRoutesOnSuccess() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowOutcome = .failedPermanently
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: populatedDraft(), submissionQueue: queue)

        await sut.submit()
        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)

        // User is back online; retapping "Accept and submit trip details" now succeeds.
        queue.submitNowOutcome = .submitted
        await sut.submit()

        XCTAssertFalse(sut.submitFailed)
        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    func test_isSubmitting_isFalseAfterSubmitCompletes() async {
        let queue = MockCatchRecordSubmissionQueue()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: populatedDraft(),
            submissionQueue: queue
        )

        await sut.submit()

        XCTAssertFalse(sut.isSubmitting)
    }

    func test_submit_whileAlreadySubmitting_doesNotCallTheQueueASecondTime() async {
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowDelayNanoseconds = 50_000_000
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: populatedDraft(),
            submissionQueue: queue
        )

        async let first: Void = sut.submit()
        async let second: Void = sut.submit()
        _ = await (first, second)

        XCTAssertEqual(queue.submitNowCallCount, 1)
    }

    // MARK: - Offline submission (BR-SUB-008/AC10/AC11 — no silent data loss, no false "submitted")

    func test_submit_whenOffline_doesNotAttemptToSend_butStillEnqueues_andRoutesToSubmissionSaved() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        let draft = populatedDraft()
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: draft, submissionQueue: queue)

        await sut.submit(isOnline: false)

        XCTAssertEqual(router.path, [.submissionSaved(referenceNumber: referenceNumber)])
        XCTAssertEqual(queue.enqueuedLocalIDs, [draft.localID], "the record must still be enqueued while offline (AC3)")
        XCTAssertEqual(queue.submitNowCallCount, 0, "no send attempt is made while offline")
    }

    func test_submit_isOnline_defaultsToTrue_soExistingCallersAreUnaffected() async {
        let router = CatchRecordRouter()
        let queue = MockCatchRecordSubmissionQueue()
        queue.submitNowOutcome = .submitted
        let sut = CheckYourAnswersViewModel(referenceNumber: referenceNumber, router: router, draft: populatedDraft(), submissionQueue: queue)

        await sut.submit() // no `isOnline:` argument — must still take the online path

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }
}
