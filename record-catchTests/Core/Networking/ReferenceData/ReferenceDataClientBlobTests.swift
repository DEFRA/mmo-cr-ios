//
//  ReferenceDataClientBlobTests.swift
//  record-catchTests
//
//  Covers `RemoteReferenceDataClient.fetchBlob(urlString:)` — the one fetch method in this
//  connector that doesn't build its request from `baseURL` + a fixed `/reference-data/{dataset}`
//  path, but instead from the manifest's own per-dataset `url` field (see ADR-0024 "Map data").
//  Split into its own file, matching the existing precedent of `ReferenceDataClientGearsTests.swift`/
//  `ReferenceDataClientErrorMappingTests.swift`.
//

import XCTest
@testable import record_catch

final class ReferenceDataClientBlobTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    private func makeConfiguration() throws -> APIConfiguration {
        try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["MMOCRAppConfig": ["API_BASE_URL": baseURL.absoluteString]]),
            allowsInsecureHTTP: true
        )
    }

    private func makeClient(httpClient: HTTPPerforming, token: String? = nil) throws -> RemoteReferenceDataClient {
        RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: token)
        )
    }

    // MARK: Absolute URLs are used as-is

    func test_fetchBlob_withAbsoluteURLString_sendsRequestToThatExactURL() async throws {
        let blobData = Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: blobData)
        let sut = try makeClient(httpClient: httpClient)

        let data = try await sut.fetchBlob(urlString: "https://cdn.example.com/map-land.json")

        XCTAssertEqual(data, blobData)
        XCTAssertEqual(httpClient.receivedRequests.first?.url?.absoluteString, "https://cdn.example.com/map-land.json")
    }

    func test_fetchBlob_withAbsoluteURLString_attachesBearerToken() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("{}".utf8))
        let sut = try makeClient(httpClient: httpClient, token: "secret-token")

        _ = try await sut.fetchBlob(urlString: "https://cdn.example.com/map-land.json")

        XCTAssertEqual(
            httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer secret-token"
        )
    }

    // MARK: Scheme-less URLs are resolved against the configured base URL

    func test_fetchBlob_withSchemeLessURLString_resolvesAgainstBaseURL() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("{}".utf8))
        let sut = try makeClient(httpClient: httpClient)

        _ = try await sut.fetchBlob(urlString: "/api/v1/reference-data/map-land/download")

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/map-land/download"
        )
    }

    // MARK: Failure mapping — identical to every other route in this connector

    func test_fetchBlob_non2xxResponse_throwsAPIErrorResponse() async throws {
        let httpClient = StubHTTPClient.statusOnly(500)
        let sut = try makeClient(httpClient: httpClient)

        do {
            _ = try await sut.fetchBlob(urlString: "https://cdn.example.com/map-land.json")
            XCTFail("Expected APIError.response")
        } catch let error as APIError {
            guard case let .response(status, _) = error else {
                return XCTFail("Expected .response, got \(error)")
            }
            XCTAssertEqual(status, 500)
        }
    }

    func test_fetchBlob_transportFailure_mapsToAPIError() async throws {
        let httpClient = StubHTTPClient.failure(URLError(.notConnectedToInternet))
        let sut = try makeClient(httpClient: httpClient)

        do {
            _ = try await sut.fetchBlob(urlString: "https://cdn.example.com/map-land.json")
            XCTFail("Expected APIError.offline")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        }
    }
}
