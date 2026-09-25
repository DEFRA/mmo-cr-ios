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

    func test_fetchVessels_throwsUnauthorized_on401() async {
        await assertMaps(statusCode: 401, to: .unauthorized)
    }

    func test_fetchVessels_throwsForbidden_on403() async {
        await assertMaps(statusCode: 403, to: .forbidden)
    }

    func test_fetchVessels_throwsNotFound_on404() async {
        await assertMaps(statusCode: 404, to: .notFound)
    }

    func test_fetchVessels_throwsTransport_onOther4xx() async {
        await assertMaps(statusCode: 418, to: .transport(code: 418))
    }

    func test_fetchVessels_throwsTransport_onStatusCodeOutsideKnownRanges() async {
        // A status code below 200 falls through every named `case` (including `2xx`, `4xx` and
        // `5xx`), reaching `throwIfError`'s `default:` branch — not expected from a real server,
        // but the mapping must still be total (see ADR-0018 §6).
        await assertMaps(statusCode: 100, to: .transport(code: 100))
    }

    func test_fetchVessels_throwsServer_on5xx() async {
        await assertMaps(statusCode: 503, to: .server(status: 503))
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

    func test_fetchVessels_throwsTransport_onUnmappedURLError() async {
        // Any `URLError` not explicitly named above (offline/timed-out) falls through to
        // `mapURLError`'s `default:` branch, carrying the raw `errorCode` (see ADR-0018 §6).
        let code = URLError.Code.cannotFindHost
        await assertMapsURLError(code, to: .transport(code: code.rawValue))
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
