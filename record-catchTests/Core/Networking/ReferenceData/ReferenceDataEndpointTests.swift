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

    // MARK: Species dataset

    func test_makeRequest_buildsExpectedURL_forSpeciesDataset() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .species,
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/species"
        )
    }

    func test_makeItemRequest_buildsExpectedURL_forSpeciesDataset() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .species,
            itemId: "5E9E48CF-7BCE-4653-ABA9-9F54591CC814",
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/species/5E9E48CF-7BCE-4653-ABA9-9F54591CC814"
        )
    }

    // MARK: Ports dataset

    func test_makeRequest_buildsExpectedURL_forPortsDataset() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .ports,
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/ports"
        )
    }

    func test_makeItemRequest_buildsExpectedURL_forPortsDataset() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .ports,
            itemId: "49e319b2-9e65-45aa-a80e-0cf4b20bfe79",
            bearerToken: nil
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/ports/49e319b2-9e65-45aa-a80e-0cf4b20bfe79"
        )
    }

    // MARK: Manifest route

    func test_makeManifestRequest_buildsExpectedURLAndMethod() {
        let request = makeReferenceDataManifestRequest(baseURL: baseURL, bearerToken: nil)

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/manifest"
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_makeManifestRequest_setsAcceptHeader() {
        let request = makeReferenceDataManifestRequest(baseURL: baseURL, bearerToken: nil)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func test_makeManifestRequest_setsAuthorizationHeader_whenTokenProvided() {
        let request = makeReferenceDataManifestRequest(baseURL: baseURL, bearerToken: "secret-token")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func test_makeManifestRequest_bypassesLocalHTTPCache() {
        // The API serves the manifest with `Cache-Control: max-age=3600`; without this override
        // `URLCache` would silently serve an hour-old manifest, defeating its purpose as a
        // change-detection signal (see ADR-0018 addendum "URLCache position").
        let request = makeReferenceDataManifestRequest(baseURL: baseURL, bearerToken: nil)

        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func test_makeManifestRequest_hasNoQueryParameters() {
        // There is deliberately no `?include=` support — the app always wants every dataset's
        // entry (see ADR-0018 addendum "Manifest").
        let request = makeReferenceDataManifestRequest(baseURL: baseURL, bearerToken: nil)

        XCTAssertNil(request.url?.query)
    }

    // MARK: Correlation header (x-cdp-request-id)

    func test_makeRequest_sendsProvidedCorrelationHeader() {
        let request = makeReferenceDataRequest(
            baseURL: baseURL,
            dataset: .vessels,
            bearerToken: nil,
            requestId: "fixed-request-id"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cdp-request-id"), "fixed-request-id")
    }

    func test_makeRequest_defaultsToANonEmptyCorrelationHeader_whenNotProvided() {
        let request = makeReferenceDataRequest(baseURL: baseURL, dataset: .vessels, bearerToken: nil)

        XCTAssertFalse(request.value(forHTTPHeaderField: "x-cdp-request-id")?.isEmpty ?? true)
    }

    func test_makeItemRequest_sendsProvidedCorrelationHeader() {
        let request = makeReferenceDataItemRequest(
            baseURL: baseURL,
            dataset: .vessels,
            itemId: "item-1",
            bearerToken: nil,
            requestId: "fixed-request-id"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cdp-request-id"), "fixed-request-id")
    }

    func test_makeManifestRequest_sendsProvidedCorrelationHeader() {
        let request = makeReferenceDataManifestRequest(
            baseURL: baseURL,
            bearerToken: nil,
            requestId: "fixed-request-id"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cdp-request-id"), "fixed-request-id")
    }

    // MARK: Fetch-all invariant — no query parameters are ever sent

    func test_makeRequest_hasNoQueryParameters_forEveryDataset() {
        for dataset: ReferenceDataset in [.vessels, .species, .ports] {
            let request = makeReferenceDataRequest(baseURL: baseURL, dataset: dataset, bearerToken: nil)
            XCTAssertNil(request.url?.query, "\(dataset) collection request must carry no query string")
        }
    }

    func test_makeItemRequest_hasNoQueryParameters_forEveryDataset() {
        for dataset: ReferenceDataset in [.vessels, .species, .ports] {
            let request = makeReferenceDataItemRequest(
                baseURL: baseURL,
                dataset: dataset,
                itemId: "item-1",
                bearerToken: nil
            )
            XCTAssertNil(request.url?.query, "\(dataset) item request must carry no query string")
        }
    }
}
