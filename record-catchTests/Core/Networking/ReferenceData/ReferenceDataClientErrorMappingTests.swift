//
//  ReferenceDataClientErrorMappingTests.swift
//  record-catchTests
//
//  Covers RemoteReferenceDataClient HTTP-status/URLError -> APIError mapping, and the
//  never-log-the-token security property (see ADR-0018 §6/§7). Error-handling paths require 100%
//  coverage per testing.instructions.md. Decoding-happy-path tests live in
//  `ReferenceDataClientTests.swift` (split to satisfy the type-body-length lint rule).
//

import XCTest
@testable import record_catch

/// Failure thrown by `ReferenceDataClientErrorMappingTests.ThrowingTokenProvider` — file-scoped
/// (rather than nested) to satisfy the app's max-nesting-depth lint rule.
private struct ThrowingTokenProviderFailure: Error {}

final class ReferenceDataClientErrorMappingTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private func loadFixture(named name: String) -> Data {
        let bundle = Bundle(for: ReferenceDataClientErrorMappingTests.self)
        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    private func loadVesselsFixture() -> Data {
        loadFixture(named: "vessels-response")
    }

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    /// Simulates a token provider that fails (e.g. a future Keychain-backed implementation
    /// encountering a read error) — the connector must proceed **without** a token rather than
    /// fail the whole request, so an unauthenticated call still reaches the real API (see
    /// `RemoteReferenceDataClient.resolvedToken()`'s `catch { return nil }`).
    private struct ThrowingTokenProvider: AuthTokenProviding {
        func bearerToken() async throws -> String? { throw ThrowingTokenProviderFailure() }
    }

    private func makeConfiguration() throws -> APIConfiguration {
        try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["APIBaseURL": baseURL.absoluteString]),
            allowsInsecureHTTP: true
        )
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    // MARK: Error mapping (fetchVessels — the full status-mapping set)

    func test_fetchVessels_throwsResponseWithUnauthorizedStatus_on401() async {
        await assertMaps(statusCode: 401, to: .response(status: 401, details: nil))
        await assertIsUnauthorized(statusCode: 401)
    }

    func test_fetchVessels_throwsResponseWithForbiddenStatus_on403() async {
        await assertMaps(statusCode: 403, to: .response(status: 403, details: nil))
        await assertIsForbidden(statusCode: 403)
    }

    func test_fetchVessels_throwsResponseWithNotFoundStatus_on404() async {
        await assertMaps(statusCode: 404, to: .response(status: 404, details: nil))
        await assertIsNotFound(statusCode: 404)
    }

    func test_fetchVessels_throwsResponse_onOther4xx() async {
        await assertMaps(statusCode: 418, to: .response(status: 418, details: nil))
    }

    func test_fetchVessels_throwsResponse_onStatusCodeOutsideKnownRanges() async {
        // A status code below 200 (and, equally, 3xx such as a bodyless 304) is not in `200..<300`
        // and so is still mapped to `.response` — the mapping must be total (see ADR-0018 §6 and
        // its "Simplified error model" addendum).
        await assertMaps(statusCode: 100, to: .response(status: 100, details: nil))
    }

    func test_fetchVessels_throwsResponseWithServiceUnavailableStatus_on503() async {
        await assertMaps(statusCode: 503, to: .response(status: 503, details: nil))
        await assertIsServiceUnavailable(statusCode: 503)
    }

    func test_fetchVessels_throwsResponse_on304NotModified() async {
        // Previously fell through to a bogus `.transport(code: 304)` — now a correctly-typed
        // `.response`, since the connector has no client-side cache to fall back on for a
        // bodyless revalidation response (see ADR-0018 addendum "304 handling").
        await assertMaps(statusCode: 304, to: .response(status: 304, details: nil))
    }

    func test_fetchVessels_decodesErrorEnvelope_fromResponseBody() async {
        let httpClient = StubHTTPClient.success(
            statusCode: 503,
            jsonData: Data("""
            {
              "error": {
                "code": "reference_data_unavailable",
                "traceId": "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11",
                "dataset": "vessels",
                "retryable": true
              }
            }
            """.utf8)
        )
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.errorCode, "reference_data_unavailable")
            XCTAssertEqual(error.traceId, "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11")
            XCTAssertTrue(error.isRetryable, "Server's own retryable: true must be honoured")
            XCTAssertTrue(error.isServiceUnavailable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessels_mapsToNilDetails_whenErrorBodyIsMalformed() async {
        let httpClient = StubHTTPClient.success(statusCode: 503, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error")
        } catch let error as APIError {
            // A malformed error body must never mask the real HTTP-status failure.
            XCTAssertEqual(error, .response(status: 503, details: nil))
            XCTAssertTrue(error.isServiceUnavailable)
            XCTAssertNil(error.errorCode)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessels_isNotRetryable_whenServerExplicitlySaysSo() async {
        let httpClient = StubHTTPClient.success(
            statusCode: 503,
            jsonData: Data("""
            { "error": { "code": "reference_data_unavailable", "retryable": false } }
            """.utf8)
        )
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertFalse(error.isRetryable, "Explicit retryable: false must override the 5xx-derived default")
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessels_throwsOffline_onNotConnectedToInternet() async {
        await assertMapsURLError(.notConnectedToInternet, to: .offline)
    }

    func test_fetchVessels_throwsOffline_onNetworkConnectionLost() async {
        await assertMapsURLError(.networkConnectionLost, to: .offline)
    }

    func test_fetchVessels_throwsTimedOut_onURLErrorTimedOut() async {
        await assertMapsURLError(.timedOut, to: .timedOut)
    }

    func test_fetchVessels_throwsResponseWithNilDetails_onUnmappedURLError() async {
        // Any `URLError` not explicitly named above (offline/timed-out) falls through to
        // `mapURLError`'s `default:` branch, carrying the raw (always-negative) `errorCode` — not
        // a real HTTP status — with no decoded envelope (see ADR-0018 §6).
        let code = URLError.Code.cannotFindHost
        await assertMapsURLError(code, to: .response(status: code.rawValue, details: nil))
    }

    // MARK: Security — never logs the token or headers

    func test_fetchVessels_proceedsWithoutToken_whenTokenProviderThrows() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: ThrowingTokenProvider()
        )

        let vessels = try await sut.fetchVessels()

        XCTAssertEqual(vessels.count, 2)
        XCTAssertNil(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_fetchVessels_neverLogsTokenOrAuthorizationHeader() async throws {
        let sink = RecordingNetworkLogSink()
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: "super-secret-token"),
            logger: NetworkLogger(sink: sink)
        )

        _ = try await sut.fetchVessels()

        XCTAssertFalse(sink.messages.isEmpty)
        for message in sink.messages {
            XCTAssertFalse(message.contains("super-secret-token"))
            XCTAssertFalse(message.contains("Authorization"))
        }
    }

    func test_fetchVessels_logsErrorCodeAndTraceId_butNeverTokenOrAuthorizationHeader_onFailure() async throws {
        let sink = RecordingNetworkLogSink()
        let httpClient = StubHTTPClient.success(
            statusCode: 503,
            jsonData: Data("""
            {
              "error": {
                "code": "reference_data_unavailable",
                "traceId": "5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11",
                "retryable": true
              }
            }
            """.utf8)
        )
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: "super-secret-token"),
            logger: NetworkLogger(sink: sink)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error")
        } catch {
            // Expected — asserting on the logged output below, not the thrown error here.
        }

        XCTAssertFalse(sink.messages.isEmpty)
        let joined = sink.messages.joined(separator: "\n")
        XCTAssertTrue(joined.contains("reference_data_unavailable"))
        XCTAssertTrue(joined.contains("5b1e6e2a-6e77-4c1a-9b3a-2e6f9a7d9c11"))
        for message in sink.messages {
            XCTAssertFalse(message.contains("super-secret-token"))
            XCTAssertFalse(message.contains("Authorization"))
        }
    }

    // MARK: Helpers

    private func assertMaps(
        statusCode: Int,
        to expected: APIError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let httpClient = StubHTTPClient.statusOnly(statusCode)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }

    private func assertIsUnauthorized(statusCode: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await assertFlag(statusCode: statusCode, flag: \.isUnauthorized, file: file, line: line)
    }

    private func assertIsForbidden(statusCode: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await assertFlag(statusCode: statusCode, flag: \.isForbidden, file: file, line: line)
    }

    private func assertIsNotFound(statusCode: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await assertFlag(statusCode: statusCode, flag: \.isNotFound, file: file, line: line)
    }

    private func assertIsServiceUnavailable(
        statusCode: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await assertFlag(statusCode: statusCode, flag: \.isServiceUnavailable, file: file, line: line)
    }

    private func assertFlag(
        statusCode: Int,
        flag: KeyPath<APIError, Bool>,
        file: StaticString,
        line: UInt
    ) async {
        let httpClient = StubHTTPClient.statusOnly(statusCode)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error", file: file, line: line)
        } catch let error as APIError {
            XCTAssertTrue(error[keyPath: flag], file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }

    private func assertMapsURLError(
        _ code: URLError.Code,
        to expected: APIError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let httpClient = StubHTTPClient.failure(URLError(code))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }
}
