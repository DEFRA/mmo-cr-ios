//
//  ReferenceDataClientHealthTests.swift
//  record-catchTests
//
//  Covers `RemoteReferenceDataClient.checkHealth()`'s happy-path behaviour (request shape, 2xx
//  success, ignoring an undocumented response body). Status-code/URLError failure mapping for
//  `checkHealth()` lives in `ReferenceDataClientErrorMappingTests.swift`. Split out of
//  `ReferenceDataClientTests.swift` to satisfy the type/file-length lint rules — matching the
//  existing precedent of `ReferenceDataClientErrorMappingTests.swift`.
//

import XCTest
@testable import record_catch

final class ReferenceDataClientHealthTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
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

    // MARK: checkHealth

    func test_checkHealth_succeeds_on200() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        try await sut.checkHealth()
    }

    func test_checkHealth_requestsHealthURL_atServiceRoot() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        try await sut.checkHealth()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/health"
        )
    }

    func test_checkHealth_throwsServiceUnavailable_on503() async {
        let httpClient = StubHTTPClient.statusOnly(503)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            try await sut.checkHealth()
            XCTFail("Expected a 503 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_checkHealth_ignoresResponseBody_whenBodyIsNotJSON() async throws {
        // The route's body shape is undocumented and deliberately not decoded (see
        // `makeReferenceDataHealthRequest`'s doc comment) — a plain-text or empty 2xx body must
        // still succeed.
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("OK".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        try await sut.checkHealth()
    }
}
