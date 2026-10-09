//
//  APIErrorTests.swift
//  record-catchTests
//
//  Unit tests for `APIError`'s own logic (`isRetryable`, `errorCode`, `traceId`, the `is*` status
//  helpers) that isn't already exercised via a real HTTP response in
//  `ReferenceDataClientErrorMappingTests`/`ReferenceDataClientTests`. Error-handling paths require
//  100% coverage per testing.instructions.md.
//

import XCTest
@testable import record_catch

final class APIErrorTests: XCTestCase {

    // MARK: - isRetryable

    func test_isRetryable_offline_isTrue() {
        XCTAssertTrue(APIError.offline.isRetryable)
    }

    func test_isRetryable_timedOut_isTrue() {
        XCTAssertTrue(APIError.timedOut.isRetryable)
    }

    func test_isRetryable_invalidConfiguration_isFalse() {
        XCTAssertFalse(APIError.invalidConfiguration.isRetryable)
    }

    func test_isRetryable_decoding_isFalse() {
        XCTAssertFalse(APIError.decoding("malformed body").isRetryable)
    }

    func test_isRetryable_response_withoutDetails_derivesFromStatus() {
        XCTAssertTrue(APIError.response(status: 503, details: nil).isRetryable)
        XCTAssertFalse(APIError.response(status: 404, details: nil).isRetryable)
    }

    func test_isRetryable_response_serverRetryableFlag_overridesStatus() {
        let nonRetryable503 = APIErrorDetails(code: "reference_data_unavailable", traceId: nil, dataset: nil, retryable: false)
        XCTAssertFalse(APIError.response(status: 503, details: nonRetryable503).isRetryable)

        let retryable400 = APIErrorDetails(code: "bad_request", traceId: nil, dataset: nil, retryable: true)
        XCTAssertTrue(APIError.response(status: 400, details: retryable400).isRetryable)
    }

    // MARK: - errorCode / traceId

    func test_errorCode_andTraceId_nilForNonResponseCases() {
        XCTAssertNil(APIError.offline.errorCode)
        XCTAssertNil(APIError.offline.traceId)
        XCTAssertNil(APIError.invalidConfiguration.errorCode)
        XCTAssertNil(APIError.timedOut.traceId)
        XCTAssertNil(APIError.decoding("x").errorCode)
    }

    func test_errorCode_andTraceId_populatedFromResponseDetails() {
        let details = APIErrorDetails(code: "reference_data_unavailable", traceId: "abc-123", dataset: "vessels", retryable: true)
        let error = APIError.response(status: 503, details: details)
        XCTAssertEqual(error.errorCode, "reference_data_unavailable")
        XCTAssertEqual(error.traceId, "abc-123")
    }

    func test_errorCode_andTraceId_nilWhenResponseHasNoDetails() {
        let error = APIError.response(status: 503, details: nil)
        XCTAssertNil(error.errorCode)
        XCTAssertNil(error.traceId)
    }

    // MARK: - is* status helpers on non-.response cases

    func test_statusFlags_allFalse_forNonResponseCases() {
        for error: APIError in [.offline, .timedOut, .invalidConfiguration, .decoding("x")] {
            XCTAssertFalse(error.isUnauthorized)
            XCTAssertFalse(error.isForbidden)
            XCTAssertFalse(error.isNotFound)
            XCTAssertFalse(error.isServiceUnavailable)
        }
    }
}
