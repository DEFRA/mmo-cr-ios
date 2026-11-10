//
//  ReferenceDataClientGearsTests.swift
//  record-catchTests
//
//  Covers `RemoteReferenceDataClient.fetchGears()` — the one dataset fetch that joins **two**
//  concurrent requests (the canonical view, the source of the required/per-trip split via
//  `applicableCharacteristics.fixed`, and the `?view=mobile` view, the source of category/
//  pair-fishing display fields and the labelled `measurements` catalogue) rather than decoding a
//  single `ReferenceDataEnvelope` (see ADR-0024 "Gears from two requests"). Split into its own
//  file (rather than `ReferenceDataClientTests.swift`) to satisfy the type/file-length lint rules —
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

    private func loadMobileFixture() -> Data {
        loadFixture(named: "gears-mobile-response")
    }

    private func loadCanonicalFixture() -> Data {
        loadFixture(named: "gears-canonical-response")
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

    private func makeClient(httpClient: HTTPPerforming) throws -> RemoteReferenceDataClient {
        RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )
    }

    // MARK: Decoding — gears (fetchGears, dual canonical + `?view=mobile` join)

    func test_fetchGears_decodesAndJoinsBothResponses_intoExpectedGearOptions() async throws {
        let httpClient = RoutingStubHTTPClient(canonicalJSON: loadCanonicalFixture(), mobileJSON: loadMobileFixture())
        let sut = try makeClient(httpClient: httpClient)

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
        XCTAssertEqual(pairTrawl.requiredMeasurements.map(\.id), ["mesh-size", "number-of-trawl-nets"])

        let dredge = try XCTUnwrap(gears.first { $0.id == "HMD" })
        XCTAssertTrue(dredge.requiredMeasurements.isEmpty)
        XCTAssertTrue(dredge.variableMeasurements.isEmpty)
        XCTAssertNil(dredge.categoryCode, "An item with no category must map to nil, not a crash")
    }

    func test_fetchGears_sendsCanonicalRequest_withNoViewParameter_andMobileRequest_withViewMobile() async throws {
        let httpClient = RoutingStubHTTPClient(canonicalJSON: loadCanonicalFixture(), mobileJSON: loadMobileFixture())
        let sut = try makeClient(httpClient: httpClient)

        _ = try await sut.fetchGears()

        let urls = httpClient.receivedRequests.compactMap { $0.url?.absoluteString }
        XCTAssertTrue(urls.contains("http://localhost:3002/api/v1/reference-data/gears"))
        XCTAssertTrue(urls.contains("http://localhost:3002/api/v1/reference-data/gears?view=mobile"))
        XCTAssertEqual(urls.count, 2)
    }

    func test_fetchGears_filtersCharacteristics_toTheDefaultUnder10mVesselLengthBand() async throws {
        // PTB's canonical fixture entry includes a `number-of-beams` characteristic scoped only to
        // "10-to-12m" — it must not appear for the app's current `under-10m`-only scope.
        let httpClient = RoutingStubHTTPClient(canonicalJSON: loadCanonicalFixture(), mobileJSON: loadMobileFixture())
        let sut = try makeClient(httpClient: httpClient)

        let gears = try await sut.fetchGears()

        let pairTrawl = try XCTUnwrap(gears.first { $0.id == "PTB" })
        XCTAssertFalse(pairTrawl.requiredMeasurements.map(\.id).contains("number-of-beams"))
    }

    func test_fetchGears_throwsGearViewsMismatch_whenVersionsDiffer() async {
        let canonicalJSON = replacingVersion(in: loadCanonicalFixture(), with: "different-version")
        let httpClient = RoutingStubHTTPClient(canonicalJSON: canonicalJSON, mobileJSON: loadMobileFixture())
        let sut = try! makeClient(httpClient: httpClient)

        do {
            _ = try await sut.fetchGears()
            XCTFail("Expected a gearViewsMismatch error")
        } catch let error as ReferenceDataValidationError {
            guard case .gearViewsMismatch = error else {
                return XCTFail("Expected .gearViewsMismatch, got \(error)")
            }
        } catch {
            XCTFail("Expected ReferenceDataValidationError, got \(error)")
        }
    }

    func test_fetchGears_throwsGearViewsMismatch_whenGearCodeSetsDiffer() async {
        let jsonString = """
        {
          "dataset": "gears",
          "collectionId": "00000000-0000-4000-8000-000000000020",
          "schemaVersion": "1.0",
          "version": "local-seed-1",
          "view": "canonical",
          "total": 1,
          "items": [ { "id": "1", "code": "ONLY-IN-CANONICAL", "name": "Only in canonical" } ]
        }
        """
        let httpClient = RoutingStubHTTPClient(canonicalJSON: Data(jsonString.utf8), mobileJSON: loadMobileFixture())
        let sut = try! makeClient(httpClient: httpClient)

        do {
            _ = try await sut.fetchGears()
            XCTFail("Expected a gearViewsMismatch error")
        } catch let error as ReferenceDataValidationError {
            guard case .gearViewsMismatch = error else {
                return XCTFail("Expected .gearViewsMismatch, got \(error)")
            }
        } catch {
            XCTFail("Expected ReferenceDataValidationError, got \(error)")
        }
    }

    func test_fetchGears_throwsUnresolvedGearMeasurement_whenCharacteristicHasNoMatchingDefinition() async {
        // The mobile fixture's `measurements` catalogue doesn't define `number-of-beams` here, but
        // the canonical fixture's TBB item references it as a fixed characteristic.
        let mobileWithoutMeasurement = """
        {
          "dataset": "gears",
          "collectionId": "00000000-0000-4000-8000-000000000020",
          "schemaVersion": "1.0",
          "version": "local-seed-1",
          "view": "mobile",
          "total": 3,
          "items": [
            { "id": "10000000-0000-4000-8000-000000000001", "code": "TBB", "name": "Beam trawl" },
            { "id": "10000000-0000-4000-8000-000000000002", "code": "PTB", "name": "Bottom pair trawl" },
            { "id": "10000000-0000-4000-8000-000000000003", "code": "HMD", "name": "Mechanised dredges" }
          ],
          "measurements": []
        }
        """
        let httpClient = RoutingStubHTTPClient(canonicalJSON: loadCanonicalFixture(), mobileJSON: Data(mobileWithoutMeasurement.utf8))
        let sut = try! makeClient(httpClient: httpClient)

        do {
            _ = try await sut.fetchGears()
            XCTFail("Expected an unresolvedGearMeasurement error")
        } catch let error as ReferenceDataValidationError {
            guard case .unresolvedGearMeasurement = error else {
                return XCTFail("Expected .unresolvedGearMeasurement, got \(error)")
            }
        } catch {
            XCTFail("Expected ReferenceDataValidationError, got \(error)")
        }
    }

    func test_fetchGears_toleratesMissingMeasurementsCatalogue_forAGearWithNoCharacteristics() async throws {
        let canonicalJSON = """
        {
          "dataset": "gears",
          "collectionId": "00000000-0000-4000-8000-000000000020",
          "schemaVersion": "1.0",
          "version": "v1",
          "view": "canonical",
          "total": 1,
          "items": [ { "id": "1", "code": "HMD", "name": "Mechanised dredges" } ]
        }
        """
        let mobileJSON = """
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
        let httpClient = RoutingStubHTTPClient(canonicalJSON: Data(canonicalJSON.utf8), mobileJSON: Data(mobileJSON.utf8))
        let sut = try makeClient(httpClient: httpClient)

        let gears = try await sut.fetchGears()

        XCTAssertEqual(gears, [GearOption(id: "HMD", name: "Mechanised dredges", referenceId: "1")])
    }

    func test_fetchGears_throwsDecoding_onMalformedJSON() async {
        let httpClient = RoutingStubHTTPClient(canonicalJSON: Data("not json".utf8), mobileJSON: Data("not json".utf8))
        let sut = try! makeClient(httpClient: httpClient)

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

    // MARK: Test helpers

    /// Replaces the fixture's `"version": "local-seed-1"` with a different value, for the
    /// mismatch test above — cheaper than hand-maintaining a second near-duplicate fixture file.
    private func replacingVersion(in json: Data, with newVersion: String) -> Data {
        let string = String(data: json, encoding: .utf8)!
        let replaced = string.replacingOccurrences(
            of: "\"version\": \"local-seed-1\"",
            with: "\"version\": \"\(newVersion)\""
        )
        return Data(replaced.utf8)
    }
}
