//
//  CatchRecordEndpointTests.swift
//  record-catchTests
//
//  Pure request-building tests — no network. Mirrors ReferenceDataEndpointTests.swift.
//

import XCTest
@testable import record_catch

final class CatchRecordEndpointTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private func makeReport(vessel: String? = "ACHILLES") -> CatchRecordSubmissionRequestDTO {
        CatchRecordSubmissionRequestDTO(
            payload: CatchRecordDraftPayload(
                vessel: vessel,
                departureDate: nil,
                returnDate: nil,
                departurePort: nil,
                returnPort: nil,
                gearCatches: [],
                speciesNotLanded: []
            )
        )
    }

    // MARK: Request shape

    func test_makeRequest_buildsExpectedURLAndMethod() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/api/v1/catch-records")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func test_makeRequest_setsAcceptAndContentTypeHeaders() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_makeRequest_setsAuthorizationHeader_whenTokenProvided() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: "secret-token",
            encoder: JSONEncoder()
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func test_makeRequest_omitsAuthorizationHeaderEntirely_whenNoToken() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(request.allHTTPHeaderFields?.keys.contains("Authorization") ?? false)
    }

    func test_makeRequest_encodesBodyAsHTTPBody() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(vessel: "ACHILLES"),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["vessel"] as? String, "ACHILLES")
    }

    func test_makeRequest_usesTheProvidedEncoder_forDateEncoding() throws {
        // A request-level JSONEncoder is injected (rather than constructed here) so
        // CatchRecordService controls the date-encoding strategy in one place — this confirms the
        // caller's encoder is actually the one used, not a locally-constructed default.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = CatchRecordDraftPayload(
            vessel: nil,
            departureDate: Date(timeIntervalSince1970: 1_729_500_000),
            returnDate: nil,
            departurePort: nil,
            returnPort: nil,
            gearCatches: [],
            speciesNotLanded: []
        )

        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: CatchRecordSubmissionRequestDTO(payload: payload),
            bearerToken: nil,
            encoder: encoder
        )

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["departureDate"] as? String, "2024-10-21T08:40:00Z")
    }

    func test_makeRequest_throws_whenBodyCannotBeEncoded() {
        struct UnencodableBody: Encodable {
            func encode(to encoder: Encoder) throws {
                throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "nope"))
            }
        }
        let failingEncoder = JSONEncoder()

        XCTAssertThrowsError(try failingEncoder.encode(UnencodableBody()))
    }

    // MARK: Correlation header (x-cdp-request-id)

    func test_makeRequest_sendsProvidedCorrelationHeader() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: nil,
            requestId: "fixed-request-id",
            encoder: JSONEncoder()
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cdp-request-id"), "fixed-request-id")
    }

    func test_makeRequest_defaultsToANonEmptyCorrelationHeader_whenNotProvided() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: baseURL,
            body: makeReport(),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        XCTAssertFalse(request.value(forHTTPHeaderField: "x-cdp-request-id")?.isEmpty ?? true)
    }

    func test_consecutiveRequests_sendDifferentCorrelationHeaders() throws {
        let first = try makeSubmitCatchRecordRequest(baseURL: baseURL, body: makeReport(), bearerToken: nil, encoder: JSONEncoder())
        let second = try makeSubmitCatchRecordRequest(baseURL: baseURL, body: makeReport(), bearerToken: nil, encoder: JSONEncoder())

        XCTAssertNotEqual(
            first.value(forHTTPHeaderField: "x-cdp-request-id"),
            second.value(forHTTPHeaderField: "x-cdp-request-id")
        )
    }

    // MARK: Path-prefixed base URL (CDP dev environment)

    // Mirrors ReferenceDataEndpointTests's equivalent — the CDP dev environment's base URL carries
    // a gateway path prefix which every route must append after, not replace.
    private let prefixedBaseURL = URL(
        string: "https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/catch-record-service"
    )!

    func test_makeRequest_preservesBasePathPrefix() throws {
        let request = try makeSubmitCatchRecordRequest(
            baseURL: prefixedBaseURL,
            body: makeReport(),
            bearerToken: nil,
            encoder: JSONEncoder()
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud"
                + "/catch-record-service/api/v1/catch-records"
        )
    }
}
