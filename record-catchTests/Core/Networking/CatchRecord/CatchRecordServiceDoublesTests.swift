//
//  CatchRecordServiceDoublesTests.swift
//  record-catchTests
//
//  Covers `StubCatchRecordService` and `FailingCatchRecordService` — the fixture-backed and
//  always-fails doubles declared alongside the production `CatchRecordService` (ADR-0025). Neither
//  is wired to a screen yet, but both are exercised here the same way `StubReferenceDataClient`/
//  `FailingReferenceDataClient` are, so their behaviour is proven before any call site depends on
//  it (testing.instructions.md — no behaviour ships untested).
//

import XCTest
@testable import record_catch

final class CatchRecordServiceDoublesTests: XCTestCase {

    // MARK: - StubCatchRecordService — returns the configured response, or a default fallback

    func test_stub_listCatchRecords_returnsConfiguredResponse() async throws {
        let response = CatchRecordListResponseDTO(items: [], limit: 20, count: 0)
        let sut = StubCatchRecordService(listResponse: response)

        let result = try await sut.listCatchRecords(limit: 20, status: nil)

        XCTAssertEqual(result, response)
    }

    func test_stub_listCatchRecords_throwsFallback_whenNoResponseConfigured() async {
        let sut = StubCatchRecordService()
        await assertThrowsServiceUnavailable { try await sut.listCatchRecords(limit: nil, status: nil) }
    }

    func test_stub_createDraft_returnsConfiguredSaveResponse() async throws {
        let saveResponse = makeSaveResponse()
        let sut = StubCatchRecordService(saveResponse: saveResponse)

        let result = try await sut.createDraft(vesselId: "v1", catchRecordReference: nil, idempotencyKey: nil)

        XCTAssertEqual(result, saveResponse)
    }

    func test_stub_createDraft_throwsFallback_whenNoResponseConfigured() async {
        let sut = StubCatchRecordService()
        await assertThrowsServiceUnavailable { try await sut.createDraft(vesselId: "v1", catchRecordReference: nil, idempotencyKey: nil) }
    }

    func test_stub_retrieveCatchRecord_throwsNotFound_whenNoResponseConfigured() async {
        let sut = StubCatchRecordService()
        do {
            _ = try await sut.retrieveCatchRecord(catchRecordId: "cr-1")
            XCTFail("Expected a 404 fallback")
        } catch let error as APIError {
            XCTAssertTrue(error.isNotFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_stub_replaceCatchRecord_returnsConfiguredSaveResponse() async throws {
        let saveResponse = makeSaveResponse()
        let sut = StubCatchRecordService(saveResponse: saveResponse)

        let result = try await sut.replaceCatchRecord(catchRecordId: "cr-1", expectedVersion: 1, payload: makeReplacementPayload())

        XCTAssertEqual(result, saveResponse)
    }

    func test_stub_saveSection_returnsConfiguredSaveResponse() async throws {
        let saveResponse = makeSaveResponse()
        let sut = StubCatchRecordService(saveResponse: saveResponse)

        let result = try await sut.saveSection(catchRecordId: "cr-1", expectedVersion: 1, section: .pairFishing(PairFishingDTO(enabled: false)))

        XCTAssertEqual(result, saveResponse)
    }

    func test_stub_abandonDraft_succeeds_whenNoErrorConfigured() async throws {
        let sut = StubCatchRecordService()
        try await sut.abandonDraft(catchRecordId: "cr-1", expectedVersion: 1)
    }

    func test_stub_abandonDraft_throwsConfiguredError() async {
        let sut = StubCatchRecordService(error: .invalidConfiguration)
        await XCTAssertThrowsErrorAsync(try await sut.abandonDraft(catchRecordId: "cr-1", expectedVersion: 1)) { error in
            XCTAssertEqual(error as? APIError, .invalidConfiguration)
        }
    }

    func test_stub_history_returnsConfiguredResponse() async throws {
        let historyResponse = CatchRecordHistoryResponseDTO(
            catchRecordId: "cr-1", status: .draft, displayStatus: .draft, version: 1,
            hasUnsubmittedChanges: false, numberOfSubmissions: 0, events: []
        )
        let sut = StubCatchRecordService(historyResponse: historyResponse)

        let result = try await sut.history(catchRecordId: "cr-1", limit: nil)

        XCTAssertEqual(result, historyResponse)
    }

    func test_stub_submit_returnsConfiguredSubmissionResponse() async throws {
        let submissionResponse = makeSubmissionResponse()
        let sut = StubCatchRecordService(submissionResponse: submissionResponse)

        let result = try await sut.submit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)

        XCTAssertEqual(result, submissionResponse)
    }

    func test_stub_listSubmissions_returnsConfiguredResponse() async throws {
        let submissionsListResponse = SubmissionsListResponseDTO(catchRecordId: "cr-1", count: 0, submissions: [])
        let sut = StubCatchRecordService(submissionsListResponse: submissionsListResponse)

        let result = try await sut.listSubmissions(catchRecordId: "cr-1")

        XCTAssertEqual(result, submissionsListResponse)
    }

    func test_stub_startEdit_returnsConfiguredSaveResponse() async throws {
        let saveResponse = makeSaveResponse()
        let sut = StubCatchRecordService(saveResponse: saveResponse)

        let result = try await sut.startEdit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)

        XCTAssertEqual(result, saveResponse)
    }

    // MARK: - FailingCatchRecordService — every method throws .invalidConfiguration, nothing else happens

    func test_failing_everyMethod_throwsInvalidConfiguration() async {
        let sut = FailingCatchRecordService()

        await XCTAssertThrowsErrorAsync(try await sut.listCatchRecords(limit: nil, status: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.createDraft(vesselId: "v1", catchRecordReference: nil, idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.retrieveCatchRecord(catchRecordId: "cr-1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.replaceCatchRecord(catchRecordId: "cr-1", expectedVersion: 1, payload: makeReplacementPayload())) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.saveSection(catchRecordId: "cr-1", expectedVersion: 1, section: .pairFishing(PairFishingDTO(enabled: false)))) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.abandonDraft(catchRecordId: "cr-1", expectedVersion: 1)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.history(catchRecordId: "cr-1", limit: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.submit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.listSubmissions(catchRecordId: "cr-1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.startEdit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
    }

    // MARK: - Fixtures

    private func makeSaveResponse() -> StandardSaveResponseDTO {
        StandardSaveResponseDTO(
            id: "cr-1", catchRecordReference: "A12345-11112026-100000", status: .draft, displayStatus: .draft,
            version: 1, savedSection: nil,
            sectionCompletion: SectionCompletionDTO(trip: false, pairFishing: false, gears: false),
            progress: CatchRecordProgressDTO(hasUnsubmittedChanges: false, numberOfSubmissions: 0, incompleteGearAssociationIds: [], currentIncompleteGearAssociationId: nil, allGearsComplete: false)
        )
    }

    private func makeSubmissionResponse() -> SubmissionResponseDTO {
        let json = Data("""
        {
          "id": "cr-1", "catchRecordReference": "A12345-11112026-100000", "status": "SUBMITTED",
          "displayStatus": "Submitted", "version": 2, "savedSection": null,
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "progress": {
            "hasUnsubmittedChanges": false, "numberOfSubmissions": 1,
            "incompleteGearAssociationIds": [], "currentIncompleteGearAssociationId": null,
            "allGearsComplete": true
          },
          "submittedAt": "2026-11-11T10:00:00Z", "submittedBy": "user-1",
          "artifacts": []
        }
        """.utf8)
        // swiftlint:disable:next force_try
        return try! CatchRecordTransport.makeDecoder().decode(SubmissionResponseDTO.self, from: json)
    }

    private func makeReplacementPayload() -> CompleteReplacementPayload {
        CompleteReplacementPayload(
            vessel: VesselSnapshotDTO(id: "v", rssSnapshot: "A1", nameSnapshot: "N", externalMarkSnapshot: "E", lengthOverallMetresSnapshot: nil),
            trip: TripDTO(startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11", departurePort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"), returnPort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N")),
            pairFishing: PairFishingDTO(enabled: false),
            gears: [],
            speciesNotLanded: []
        )
    }

    private func assertThrowsServiceUnavailable(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await operation()
            XCTFail("Expected an error", file: file, line: line)
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }
}

/// Shared async-throwing assertion helper (XCTest has no built-in async `XCTAssertThrowsError`).
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
