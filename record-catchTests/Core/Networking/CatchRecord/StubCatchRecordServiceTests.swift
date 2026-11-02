//
//  StubCatchRecordServiceTests.swift
//  record-catchTests
//
//  Covers `StubCatchRecordService`, the fixture-backed double provided alongside
//  `CatchRecordService` for future call sites/tests. Mirrors StubReferenceDataClientTests.swift.
//

import XCTest
@testable import record_catch

final class StubCatchRecordServiceTests: XCTestCase {

    private func makeReport() -> CatchRecordSubmissionRequestDTO {
        CatchRecordSubmissionRequestDTO(
            payload: CatchRecordDraftPayload(
                vessel: "ACHILLES",
                departureDate: nil,
                returnDate: nil,
                departurePort: nil,
                returnPort: nil,
                gearCatches: [],
                speciesNotLanded: []
            )
        )
    }

    func test_submitCatchReport_returnsConfiguredResponse() async throws {
        let sut = StubCatchRecordService(response: CatchRecordSubmissionResponseDTO(referenceNumber: "CR-0001"))

        let result = try await sut.submitCatchReport(makeReport())

        XCTAssertEqual(result.referenceNumber, "CR-0001")
    }

    func test_submitCatchReport_throwsConfiguredError() async {
        let sut = StubCatchRecordService(error: .response(status: 401, details: nil))

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .response(status: 401, details: nil))
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_throwsServiceUnavailable_whenNoResponseConfigured() async {
        let sut = StubCatchRecordService()

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected a 503 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
