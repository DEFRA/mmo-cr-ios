//
//  CatchRecordPlatformServiceTests.swift
//  record-catchTests
//
//  Covers `CatchRecordPlatformService` — `/health` and `/example` are both unauthenticated
//  (`security: []`), so the key assertion is that no `Authorization` header is ever attached even
//  when a token is available.
//

import XCTest
@testable import record_catch

final class CatchRecordPlatformServiceTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    private func makeSUT(httpClient: HTTPPerforming) throws -> CatchRecordPlatformService {
        let configuration = try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["MMOCRAppConfig": ["API_BASE_URL": baseURL.absoluteString]]),
            allowsInsecureHTTP: true
        )
        return CatchRecordPlatformService(httpClient: httpClient, configuration: configuration, tokenProvider: StaticTokenProvider(token: "secret"))
    }

    func test_checkHealth_succeeds_on200() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"message":"success"}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        try await sut.checkHealth()

        XCTAssertNil(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_checkHealth_throws_onNon2xx() async throws {
        let httpClient = StubHTTPClient.statusOnly(503)
        let sut = try makeSUT(httpClient: httpClient)

        do {
            try await sut.checkHealth()
            XCTFail("Expected a 503 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable)
        }
    }

    func test_listExampleData_decodesRawDocuments_withNoAuthorizationHeader() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"[{"name":"demo","count":3}]"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        let items = try await sut.listExampleData()

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }
}
