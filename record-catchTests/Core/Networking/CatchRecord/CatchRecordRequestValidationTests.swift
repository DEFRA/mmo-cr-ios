//
//  CatchRecordRequestValidationTests.swift
//  record-catchTests
//
//  Covers `CatchRecordRequestValidation` — every client-side precondition check must throw
//  `APIError.invalidRequest` and never allow a request to be built when it fails (ADR-0025
//  "Checks before sending"). These are security/correctness-adjacent guards, so covered
//  exhaustively per testing.instructions.md's 100% target for error-handling paths.
//

import XCTest
@testable import record_catch

final class CatchRecordRequestValidationTests: XCTestCase {

    // MARK: version

    func test_validateVersion_accepts1AndAbove() {
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateVersion(1))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateVersion(1000))
    }

    func test_validateVersion_rejectsZeroAndNegative() {
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateVersion(0))
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateVersion(-1))
    }

    // MARK: limit

    func test_validateLimit_acceptsNilAndInRange() {
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateLimit(nil))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateLimit(1))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateLimit(100))
    }

    func test_validateLimit_rejectsOutOfRange() {
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateLimit(0))
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateLimit(101))
    }

    // MARK: submissionNumber

    func test_validateSubmissionNumber_acceptsInRange() {
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateSubmissionNumber(1))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateSubmissionNumber(1000))
    }

    func test_validateSubmissionNumber_rejectsOutOfRange() {
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateSubmissionNumber(0))
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateSubmissionNumber(1001))
    }

    // MARK: Idempotency-Key

    func test_validateIdempotencyKey_acceptsNilAndInRange() {
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateIdempotencyKey(nil))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateIdempotencyKey("a"))
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateIdempotencyKey(String(repeating: "a", count: 256)))
    }

    func test_validateIdempotencyKey_rejectsEmptyOrTooLong() {
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateIdempotencyKey(""))
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateIdempotencyKey(String(repeating: "a", count: 257)))
    }

    // MARK: Replacement payload size

    func test_validateReplacementPayloadSize_acceptsUpToOneMebibyte() {
        XCTAssertNoThrow(try CatchRecordRequestValidation.validateReplacementPayloadSize(Data(count: 1024 * 1024)))
    }

    func test_validateReplacementPayloadSize_rejectsOverOneMebibyte() {
        XCTAssertThrowsError(try CatchRecordRequestValidation.validateReplacementPayloadSize(Data(count: 1024 * 1024 + 1)))
    }
}
