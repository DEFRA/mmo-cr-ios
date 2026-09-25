//
//  ReferenceDataClientTests.swift
//  record-catchTests
//
//  Covers RemoteReferenceDataClient decoding for both the collection route (`fetchVessels()`) and
//  the single-item route (`fetchVessel(id:)`) — see ADR-0018 §2/§6. Status-code/URLError mapping
//  and the never-log-the-token security property live in
//  `ReferenceDataClientErrorMappingTests.swift` (split to satisfy the type-body-length lint rule).
//

import XCTest
@testable import record_catch

final class ReferenceDataClientTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!
    private let vesselId = "00000000-0000-4000-8000-000000000011"

    private func loadFixture(named name: String) -> Data {
        let bundle = Bundle(for: ReferenceDataClientTests.self)
        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    private func loadVesselsFixture() -> Data {
        loadFixture(named: "vessels-response")
    }

    private func loadVesselItemFixture() -> Data {
        loadFixture(named: "vessel-item-response")
    }

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
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

    // MARK: Decoding — collection route (fetchVessels)

    func test_fetchVessels_decodesFixture_intoExpectedVesselOptions() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let vessels = try await sut.fetchVessels()

        XCTAssertEqual(vessels.count, 2)
        XCTAssertEqual(vessels[0].id, "00000000-0000-4000-8000-000000000011")
        XCTAssertEqual(vessels[0].displayName, "ACHILLES PH1234")
        XCTAssertEqual(vessels[1].name, "SEA SPRAY")
        XCTAssertEqual(vessels[1].lengthOverallMetres, 11.2)
    }

    func test_fetchVessels_toleratesMinimalVessel_withOnlyIdAndName() async throws {
        let jsonString = """
        {
          "dataset": "vessels",
          "collectionId": "00000000-0000-4000-8000-000000000010",
          "schemaVersion": "1.0",
          "version": "v1",
          "view": "canonical",
          "total": 1,
          "items": [ { "id": "1", "name": "MINIMAL" } ]
        }
        """
        let json = Data(jsonString.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let vessels = try await sut.fetchVessels()

        XCTAssertEqual(vessels, [VesselOption(id: "1", name: "MINIMAL")])
    }

    func test_fetchVessels_requestsCollectionURL_withNoItemIdSegment() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchVessels()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/vessels"
        )
    }

    // MARK: Decoding — single-item route (fetchVessel)

    func test_fetchVessel_decodesBareItemFixture_intoExpectedVesselOption() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let vessel = try await sut.fetchVessel(id: vesselId)

        XCTAssertEqual(vessel.id, vesselId)
        XCTAssertEqual(vessel.displayName, "ACHILLES PH1234")
    }

    func test_fetchVessel_requestsItemURL_withPercentEncodedId() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchVessel(id: "id with spaces")

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/vessels/id%20with%20spaces"
        )
    }

    func test_fetchVessel_throwsNotFound_on404() async {
        let httpClient = StubHTTPClient.statusOnly(404)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessel(id: "unknown-id")
            XCTFail("Expected .notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessel_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessel(id: vesselId)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessels_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
