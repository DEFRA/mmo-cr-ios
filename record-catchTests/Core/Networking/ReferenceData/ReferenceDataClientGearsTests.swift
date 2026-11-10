//
//  ReferenceDataClientGearsTests.swift
//  record-catchTests
//
//  Covers `RemoteReferenceDataClient.fetchGears()` — the one dataset route that requests
//  `?view=mobile` and decodes into its own `GearsMobileResponseDTO` rather than the shared
//  `ReferenceDataEnvelope` (see ADR-0018 addendum "gears dataset"). Split into its own file
//  (rather than `ReferenceDataClientTests.swift`) to satisfy the type/file-length lint rules —
//  matching the existing precedent of `ReferenceDataClientErrorMappingTests.swift`.
//

import XCTest
@testable import record_catch

final class ReferenceDataClientGearsTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private func loadFixture(named name: String) -> Data {
        let bundle = Bundle(for: ReferenceDataClientGearsTests.self)
        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    private func loadGearsFixture() -> Data {
        loadFixture(named: "gears-mobile-response")
    }

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

    // MARK: Decoding — gears (fetchGears, `?view=mobile`)

    func test_fetchGears_decodesFixture_intoExpectedGearOptions() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadGearsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let gears = try await sut.fetchGears()

        XCTAssertEqual(gears.count, 3)
        let beamTrawl = try XCTUnwrap(gears.first { $0.id == "TBB" })
        XCTAssertEqual(beamTrawl.name, "Beam trawl")
        XCTAssertEqual(beamTrawl.referenceId, "10000000-0000-4000-8000-000000000001")
        XCTAssertEqual(beamTrawl.categoryCode, "TRAWL_NETS")
        XCTAssertEqual(beamTrawl.categoryName, "Trawl nets")
        XCTAssertEqual(beamTrawl.isPairFishing, false)
        XCTAssertEqual(beamTrawl.requiredMeasurements.map(\.id), ["mesh-size", "number-of-beams"])
        XCTAssertEqual(beamTrawl.requiredMeasurements.first?.labelKey, "Mesh size (mm)")
        XCTAssertEqual(beamTrawl.requiredMeasurements.first?.apiCode, "ME")
        XCTAssertEqual(beamTrawl.requiredMeasurements.first?.unit, "mm")
        XCTAssertEqual(beamTrawl.variableMeasurements.map(\.id), ["times-shot"])

        let pairTrawl = try XCTUnwrap(gears.first { $0.id == "PTB" })
        XCTAssertEqual(pairTrawl.isPairFishing, true)

        let dredge = try XCTUnwrap(gears.first { $0.id == "HMD" })
        XCTAssertTrue(dredge.requiredMeasurements.isEmpty)
        XCTAssertTrue(dredge.variableMeasurements.isEmpty)
        XCTAssertNil(dredge.categoryCode, "An item with no category must map to nil, not a crash")
    }

    func test_fetchGears_requestsMobileViewQueryParameter() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadGearsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchGears()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/gears?view=mobile"
        )
    }

    func test_fetchGears_toleratesMissingMeasurementsCatalogue() async throws {
        let jsonString = """
        {
          "dataset": "gears",
          "collectionId": "00000000-0000-4000-8000-000000000020",
          "schemaVersion": "1.0",
          "version": "v1",
          "view": "mobile",
          "total": 1,
          "items": [ { "id": "1", "code": "HMD", "name": "Mechanised dredges" } ]
        }
        """
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(jsonString.utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let gears = try await sut.fetchGears()

        XCTAssertEqual(gears, [GearOption(id: "HMD", name: "Mechanised dredges", referenceId: "1")])
    }

    func test_fetchGears_dropsUnresolvedMeasurementId_ratherThanFailing() async throws {
        // A measurement id with no matching entry in the response's `measurements` catalogue must
        // be dropped, not crash the whole fetch (see `GearOption.make(dto:measurementsById:)`).
        let jsonString = """
        {
          "dataset": "gears",
          "collectionId": "00000000-0000-4000-8000-000000000020",
          "schemaVersion": "1.0",
          "version": "v1",
          "view": "mobile",
          "total": 1,
          "items": [
            {
              "id": "1",
              "code": "TBB",
              "name": "Beam trawl",
              "requiredMeasurementIds": ["unknown-measurement-id"]
            }
          ],
          "measurements": []
        }
        """
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(jsonString.utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let gears = try await sut.fetchGears()

        XCTAssertEqual(gears.count, 1)
        XCTAssertTrue(gears[0].requiredMeasurements.isEmpty)
    }

    func test_fetchGears_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchGears()
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
