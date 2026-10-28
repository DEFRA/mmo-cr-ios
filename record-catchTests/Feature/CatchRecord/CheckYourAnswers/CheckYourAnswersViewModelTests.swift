import XCTest
@testable import record_catch

/// Always-succeeding stub submission service for exercising the happy path deterministically,
/// with no real delay.
private struct StubSuccessSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {}
}

private struct StubFailingSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {
        throw CatchRecordSubmissionError.network
    }
}

/// Mutable mock so a single view model instance can be retried after a failure — the first
/// `submit()` fails, the second succeeds — to test the "clears submitFailed on retry" behaviour
/// without recreating the view model (as a real retry-after-reconnect would look).
private final class MockRetrySubmissionService: CatchRecordSubmissionServicing, @unchecked Sendable {
    var shouldFail = true

    func submit(referenceNumber: String) async throws {
        if shouldFail { throw CatchRecordSubmissionError.network }
    }
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

    // MARK: - Submit

    func test_submit_whenOnline_pushesSubmissionSuccessOntoRouter_andDeletesTheDraft() async throws {
        let router = CatchRecordRouter()
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = populatedDraft()
        try await draftStore.save(draft)
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: draft,
            submissionService: StubSuccessSubmissionService(),
            draftStore: draftStore
        )

        await sut.submit()

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
        // Allow the fire-and-forget deletion Task to run (see `DraftActionViewModelTests`'
        // equivalent pattern for the same fire-and-forget delete shape).
        try? await Task.sleep(nanoseconds: 10_000_000)
        let loaded = try await draftStore.loadDraft(localID: draft.localID)
        XCTAssertNil(loaded, "a successfully submitted draft must be deleted so it no longer shows as Unsent")
    }

    // MARK: - Submission failure (error-handling path — 100% coverage requirement)

    func test_submit_whenSubmissionServiceFails_setsSubmitFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: populatedDraft(),
            submissionService: StubFailingSubmissionService()
        )

        await sut.submit()

        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_retryAfterFailure_clearsSubmitFailed_andRoutesOnSuccess() async {
        let router = CatchRecordRouter()
        let service = MockRetrySubmissionService()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: populatedDraft(),
            submissionService: service
        )

        await sut.submit()
        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)

        // User is back online; retapping "Accept and submit trip details" now succeeds.
        service.shouldFail = false
        await sut.submit()

        XCTAssertFalse(sut.submitFailed)
        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    func test_isSubmitting_isFalseAfterSubmitCompletes() async {
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: populatedDraft(),
            submissionService: StubSuccessSubmissionService()
        )

        await sut.submit()

        XCTAssertFalse(sut.isSubmitting)
    }

    /// A single-use spy that fails the test if `submit()` is ever called more than once,
    /// guarding against a double tap re-entering an in-flight submission.
    private final class CountingSubmissionService: CatchRecordSubmissionServicing, @unchecked Sendable {
        private(set) var callCount = 0

        func submit(referenceNumber: String) async throws {
            callCount += 1
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func test_submit_whileAlreadySubmitting_doesNotCallTheServiceASecondTime() async {
        let service = CountingSubmissionService()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: populatedDraft(),
            submissionService: service
        )

        async let first: Void = sut.submit()
        async let second: Void = sut.submit()
        _ = await (first, second)

        XCTAssertEqual(service.callCount, 1)
    }

    // MARK: - Offline submission (BR-SUB-008/AC10/AC11 — no silent data loss, no false "submitted")

    /// A fail-if-called spy: proves the (stubbed) submission service is never invoked while
    /// offline — the record must not be claimed as submitted when nothing was sent.
    private struct FailIfCalledSubmissionService: CatchRecordSubmissionServicing {
        func submit(referenceNumber: String) async throws {
            XCTFail("the submission service must not be called while offline")
        }
    }

    func test_submit_whenOffline_doesNotCallTheSubmissionService_andRoutesToSubmissionSaved() async {
        let router = CatchRecordRouter()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: populatedDraft(),
            submissionService: FailIfCalledSubmissionService()
        )

        await sut.submit(isOnline: false)

        XCTAssertEqual(router.path, [.submissionSaved(referenceNumber: referenceNumber)])
    }

    func test_submit_whenOffline_doesNotDeleteThePersistedDraft() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = populatedDraft()
        try await draftStore.save(draft)
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: draft,
            submissionService: FailIfCalledSubmissionService(),
            draftStore: draftStore
        )

        await sut.submit(isOnline: false)

        let loaded = try await draftStore.loadDraft(localID: draft.localID)
        XCTAssertNotNil(loaded, "the draft must remain resumable — nothing was submitted")
    }

    func test_submit_isOnline_defaultsToTrue_soExistingCallersAreUnaffected() async {
        let router = CatchRecordRouter()
        let sut = CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: populatedDraft(),
            submissionService: StubSuccessSubmissionService()
        )

        await sut.submit() // no `isOnline:` argument — must still take the online path

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }
}
