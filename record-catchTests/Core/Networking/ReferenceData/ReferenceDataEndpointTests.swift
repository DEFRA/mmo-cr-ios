//
//  ReferenceDataEndpointTests.swift
//  record-catchTests
//
//  Pure request-building tests — no network. See ADR-0018 §4.
//

import XCTest
@testable import record_catch

final class ReferenceDataEndpointTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    // MARK: Collection route

    func test_makeRequest_buildsExpectedURLAndMethod() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .vessels,
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/vessels"
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_makeRequest_setsAcceptHeader() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .vessels,
            bearerToken: nil
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func test_makeRequest_setsAuthorizationHeader_whenTokenProvided() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .vessels,
            bearerToken: "secret-token"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func test_makeRequest_omitsAuthorizationHeaderEntirely_whenNoToken() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .vessels,
            bearerToken: nil
        )

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(request.allHTTPHeaderFields?.keys.contains("Authorization") ?? false)
    }

    // MARK: Single-item route

    func test_makeItemRequest_buildsExpectedURLAndMethod() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "00000000-0000-4000-8000-000000000011",
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/vessels/00000000-0000-4000-8000-000000000011"
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_makeItemRequest_setsAcceptHeader() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "item-1",
            bearerToken: nil
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func test_makeItemRequest_setsAuthorizationHeader_whenTokenProvided() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "item-1",
            bearerToken: "secret-token"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func test_makeItemRequest_omitsAuthorizationHeaderEntirely_whenNoToken() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "item-1",
            bearerToken: nil
        )

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(request.allHTTPHeaderFields?.keys.contains("Authorization") ?? false)
    }

    func test_makeItemRequest_percentEncodesItemId() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "item with spaces",
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/vessels/item%20with%20spaces"
        )
    }
}
