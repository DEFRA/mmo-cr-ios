//
//  CatchRecordServiceTests.swift
//  record-catchTests
//
//  Covers CatchRecordService: happy-path submission, HTTP-status/URLError -> APIError mapping, and
//  the never-log-the-token security property. Mirrors ReferenceDataClientTests.swift/
//  ReferenceDataClientErrorMappingTests.swift, condensed into one file since this connector has a
//  single route.
//

import XCTest
@testable import record_catch

/// Failure thrown by `ThrowingTokenProvider` below — file-scoped rather than nested to satisfy the
/// app's max-nesting-depth lint rule (mirrors `ThrowingTokenProviderFailure` in
/// ReferenceDataClientErrorMappingTests.swift).
private struct CatchRecordThrowingTokenProviderFailure: Error {}

final class CatchRecordServiceTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    /// Simulates a token provider that fails — the connector must proceed **without** a token
    /// rather than fail the whole request (mirrors `RemoteReferenceDataClient.resolvedToken()`).
    private struct ThrowingTokenProvider: AuthTokenProviding {
        func bearerToken() async throws -> String? { throw CatchRecordThrowingTokenProviderFailure() }
    }

    private func makeConfiguration() throws -> APIConfiguration {
        try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["MMOCRAppConfig": ["API_BASE_URL": baseURL.absoluteString]]),
            allowsInsecureHTTP: true
        )
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

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

    // MARK: Happy path

    func test_submitCatchReport_decodesReferenceNumber_onSuccess() async throws {
        let httpClient = StubHTTPClient.success(
            statusCode: 201,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let response = try await sut.submitCatchReport(makeReport())

        XCTAssertEqual(response.referenceNumber, "CR-0001")
    }

    func test_submitCatchReport_sendsPOSTToExpectedURL() async throws {
        let httpClient = StubHTTPClient.success(
            statusCode: 200,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.submitCatchReport(makeReport())

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "POST")
        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/catch-records"
        )
    }

    func test_submitCatchReport_encodesDatesAsISO8601_notTheDefaultReferenceDateEncoding() async throws {
        // The connector must not inherit `Date`'s default Codable encoding (seconds since the 2001
        // reference date) — that's only acceptable for the on-device draft store, never a wire API.
        let httpClient = StubHTTPClient.success(
            statusCode: 200,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )
        let payload = CatchRecordDraftPayload(
            vessel: nil,
            departureDate: Date(timeIntervalSince1970: 1_729_500_000),
            returnDate: nil,
            departurePort: nil,
            returnPort: nil,
            gearCatches: [],
            speciesNotLanded: []
        )

        _ = try await sut.submitCatchReport(CatchRecordSubmissionRequestDTO(payload: payload))

        let body = try XCTUnwrap(httpClient.receivedRequests.first?.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["departureDate"] as? String, "2024-10-21T08:40:00Z")
    }

    func test_submitCatchReport_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: Error mapping

    func test_submitCatchReport_throwsResponseWithUnauthorizedStatus_on401() async {
        let httpClient = StubHTTPClient.statusOnly(401)
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected a 401 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_throwsResponseWithServiceUnavailableStatus_on503() async {
        let httpClient = StubHTTPClient.statusOnly(503)
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected a 503 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_decodesErrorEnvelope_fromResponseBody() async {
        let httpClient = StubHTTPClient.success(
            statusCode: 503,
            jsonData: Data("""
            {
              "error": {
                "code": "catch_record_service_unavailable",
                "traceId": "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11",
                "retryable": true
              }
            }
            """.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.errorCode, "catch_record_service_unavailable")
            XCTAssertEqual(error.traceId, "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11")
            XCTAssertTrue(error.isRetryable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_mapsToNilDetails_whenErrorBodyIsMalformed() async {
        let httpClient = StubHTTPClient.success(statusCode: 503, jsonData: Data("not json".utf8))
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .response(status: 503, details: nil))
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_throwsOffline_onNotConnectedToInternet() async {
        let httpClient = StubHTTPClient.failure(URLError(.notConnectedToInternet))
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected .offline")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_throwsTimedOut_onURLErrorTimedOut() async {
        let httpClient = StubHTTPClient.failure(URLError(.timedOut))
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected .timedOut")
        } catch let error as APIError {
            XCTAssertEqual(error, .timedOut)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_submitCatchReport_throwsResponseWithNilDetails_onUnmappedURLError() async {
        let code = URLError.Code.cannotFindHost
        let httpClient = StubHTTPClient.failure(URLError(code))
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected .response")
        } catch let error as APIError {
            XCTAssertEqual(error, .response(status: code.rawValue, details: nil))
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: Security — never logs the token or headers

    func test_submitCatchReport_proceedsWithoutToken_whenTokenProviderThrows() async throws {
        let httpClient = StubHTTPClient.success(
            statusCode: 200,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: ThrowingTokenProvider()
        )

        let response = try await sut.submitCatchReport(makeReport())

        XCTAssertEqual(response.referenceNumber, "CR-0001")
        XCTAssertNil(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_submitCatchReport_neverLogsTokenOrAuthorizationHeader() async throws {
        let sink = RecordingNetworkLogSink()
        let httpClient = StubHTTPClient.success(
            statusCode: 200,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: "super-secret-token"),
            logger: NetworkLogger(sink: sink)
        )

        _ = try await sut.submitCatchReport(makeReport())

        XCTAssertFalse(sink.messages.isEmpty)
        for message in sink.messages {
            XCTAssertFalse(message.contains("super-secret-token"))
            XCTAssertFalse(message.contains("Authorization"))
        }
    }

    func test_submitCatchReport_logsErrorCodeAndTraceId_butNeverTokenOrAuthorizationHeader_onFailure() async throws {
        let sink = RecordingNetworkLogSink()
        let httpClient = StubHTTPClient.success(
            statusCode: 503,
            jsonData: Data("""
            {
              "error": {
                "code": "catch_record_service_unavailable",
                "traceId": "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11",
                "retryable": true
              }
            }
            """.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: "super-secret-token"),
            logger: NetworkLogger(sink: sink)
        )

        do {
            _ = try await sut.submitCatchReport(makeReport())
            XCTFail("Expected an error")
        } catch {
            // Expected — asserting on the logged output below, not the thrown error here.
        }

        XCTAssertFalse(sink.messages.isEmpty)
        let joined = sink.messages.joined(separator: "\n")
        XCTAssertTrue(joined.contains("catch_record_service_unavailable"))
        for message in sink.messages {
            XCTAssertFalse(message.contains("super-secret-token"))
            XCTAssertFalse(message.contains("Authorization"))
        }
    }

    // MARK: Correlation header (x-cdp-request-id)

    func test_submitCatchReport_sendsCorrelationHeader() async throws {
        let httpClient = StubHTTPClient.success(
            statusCode: 200,
            jsonData: Data(#"{ "referenceNumber": "CR-0001" }"#.utf8)
        )
        let sut = CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.submitCatchReport(makeReport())

        let requestId = httpClient.receivedRequests.first?.value(forHTTPHeaderField: "x-cdp-request-id")
        XCTAssertNotNil(requestId)
        XCTAssertFalse(requestId?.isEmpty ?? true)
    }
}
