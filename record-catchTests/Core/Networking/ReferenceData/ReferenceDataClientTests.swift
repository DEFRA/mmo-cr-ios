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

    private func loadSpeciesFixture() -> Data {
        loadFixture(named: "species-response")
    }

    private func loadSpeciesItemFixture() -> Data {
        loadFixture(named: "species-item-response")
    }

    private func loadPortsFixture() -> Data {
        loadFixture(named: "ports-response")
    }

    private func loadPortItemFixture() -> Data {
        loadFixture(named: "port-item-response")
    }

    private func loadManifestFixture() -> Data {
        loadFixture(named: "manifest-response")
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
            XCTFail("Expected a 404 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isNotFound)
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

    // MARK: Decoding — collection route (fetchSpecies)

    func test_fetchSpecies_decodesFixture_intoExpectedSpeciesOptions() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadSpeciesFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let species = try await sut.fetchSpecies()

        XCTAssertEqual(species.count, 3)
        XCTAssertEqual(species[0].id, "5E9E48CF-7BCE-4653-ABA9-9F54591CC814")
        XCTAssertEqual(species[0].name, "Queen scallop (QSC)")
        XCTAssertEqual(species[1].name, "Alepocephalus bairdii (ALC)")
        XCTAssertEqual(species[2].name, "00000000-0000-4000-8000-000000000099")
    }

    func test_fetchSpecies_toleratesMinimalSpecies_withOnlyId() async throws {
        let jsonString = """
        {
          "dataset": "species",
          "collectionId": "00000000-0000-4000-8000-000000000040",
          "schemaVersion": "1.0",
          "version": "v1",
          "view": "canonical",
          "total": 1,
          "items": [ { "id": "1" } ]
        }
        """
        let json = Data(jsonString.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let species = try await sut.fetchSpecies()

        XCTAssertEqual(species, [SpeciesOption(id: "1", name: "1")])
    }

    func test_fetchSpecies_requestsCollectionURL_withNoItemIdSegment() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadSpeciesFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchSpecies()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/species"
        )
    }

    // MARK: Decoding — single-item route (fetchSpecies(id:))

    func test_fetchSpeciesItem_decodesBareItemFixture_intoExpectedSpeciesOption() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadSpeciesItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let species = try await sut.fetchSpecies(id: "5E9E48CF-7BCE-4653-ABA9-9F54591CC814")

        XCTAssertEqual(species.id, "5E9E48CF-7BCE-4653-ABA9-9F54591CC814")
        XCTAssertEqual(species.name, "Queen scallop (QSC)")
    }

    func test_fetchSpeciesItem_requestsItemURL_withPercentEncodedId() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadSpeciesItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchSpecies(id: "id with spaces")

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/species/id%20with%20spaces"
        )
    }

    func test_fetchSpeciesItem_throwsNotFound_on404() async {
        let httpClient = StubHTTPClient.statusOnly(404)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchSpecies(id: "unknown-id")
            XCTFail("Expected a 404 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isNotFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchSpeciesItem_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchSpecies(id: "5E9E48CF-7BCE-4653-ABA9-9F54591CC814")
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchSpecies_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchSpecies()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: Decoding — collection route (fetchPorts)

    func test_fetchPorts_decodesFixture_intoExpectedPortOptions() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadPortsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let ports = try await sut.fetchPorts()

        XCTAssertEqual(ports.count, 3)
        XCTAssertEqual(ports[0].id, "49e319b2-9e65-45aa-a80e-0cf4b20bfe79")
        XCTAssertEqual(ports[0].name, "Abbotsbury")
        XCTAssertEqual(ports[0].code, "GBAOT")
        XCTAssertEqual(ports[0].countryCode, "GBR")
        XCTAssertEqual(ports[0].coordinate, PortCoordinate(latitude: 50.6666984558105, longitude: -2.59999990463257))
        XCTAssertEqual(ports[0].isActive, true)
        XCTAssertEqual(ports[1].name, "Fowey")
        XCTAssertNil(ports[1].coordinate, "A handful of real ports have no coordinate — must not fail to decode")
    }

    func test_fetchPorts_toleratesMinimalPort_withOnlyIdAndName() async throws {
        let jsonString = """
        {
          "dataset": "ports",
          "collectionId": "00000000-0000-4000-8000-000000000030",
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

        let ports = try await sut.fetchPorts()

        XCTAssertEqual(ports, [PortOption(id: "1", name: "MINIMAL")])
    }

    func test_fetchPorts_requestsCollectionURL_withNoItemIdSegment() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadPortsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchPorts()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/ports"
        )
    }

    // MARK: Decoding — single-item route (fetchPort(id:))

    func test_fetchPortItem_decodesBareItemFixture_intoExpectedPortOption() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadPortItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let port = try await sut.fetchPort(id: "49e319b2-9e65-45aa-a80e-0cf4b20bfe79")

        XCTAssertEqual(port.id, "49e319b2-9e65-45aa-a80e-0cf4b20bfe79")
        XCTAssertEqual(port.name, "Abbotsbury")
        XCTAssertEqual(port.code, "GBAOT")
    }

    func test_fetchPortItem_requestsItemURL_withPercentEncodedId() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadPortItemFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchPort(id: "id with spaces")

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/ports/id%20with%20spaces"
        )
    }

    func test_fetchPortItem_throwsNotFound_on404() async {
        let httpClient = StubHTTPClient.statusOnly(404)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchPort(id: "unknown-id")
            XCTFail("Expected a 404 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isNotFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchPortItem_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchPort(id: "49e319b2-9e65-45aa-a80e-0cf4b20bfe79")
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchPorts_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchPorts()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: Decoding — manifest (fetchManifest)

    func test_fetchManifest_decodesFixture_intoExpectedManifest() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadManifestFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        let manifest = try await sut.fetchManifest()

        XCTAssertEqual(manifest.manifestId, "00000000-0000-4000-8000-000000000001")
        XCTAssertEqual(manifest.datasets.count, 6)
        let ports = manifest.datasets.first { $0.dataset == "ports" }
        XCTAssertEqual(ports?.itemCount, 624)
        // Entries for datasets the app doesn't model yet (`gears`, `map-land`,
        // `map-statistical-areas`) must decode harmlessly rather than failing the manifest.
        XCTAssertTrue(manifest.datasets.contains { $0.dataset == "gears" })
        XCTAssertTrue(manifest.datasets.contains { $0.dataset == "map-land" })
        XCTAssertTrue(manifest.datasets.contains { $0.dataset == "map-statistical-areas" })
    }

    func test_fetchManifest_requestsManifestURL() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadManifestFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchManifest()

        XCTAssertEqual(
            httpClient.receivedRequests.first?.url?.absoluteString,
            "http://localhost:3002/api/v1/reference-data/manifest"
        )
    }

    func test_fetchManifest_bypassesLocalHTTPCache() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadManifestFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchManifest()

        // Without this, `URLCache` would silently serve an up-to-an-hour-stale manifest (the API
        // sends `Cache-Control: max-age=3600`), defeating its purpose as a change-detection
        // signal (see ADR-0018 addendum "URLCache position").
        XCTAssertEqual(httpClient.receivedRequests.first?.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func test_fetchManifest_throwsDecoding_onMalformedJSON() async {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data("not json".utf8))
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchManifest()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchManifest_throwsServiceUnavailable_on503() async {
        let httpClient = StubHTTPClient.statusOnly(503)
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try! makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        do {
            _ = try await sut.fetchManifest()
            XCTFail("Expected a 503 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isServiceUnavailable)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
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

    // MARK: Correlation header (x-cdp-request-id)

    func test_everyRequest_sendsCorrelationHeader() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchVessels()

        let requestId = httpClient.receivedRequests.first?.value(forHTTPHeaderField: "x-cdp-request-id")
        XCTAssertNotNil(requestId)
        XCTAssertFalse(requestId?.isEmpty ?? true)
    }

    func test_consecutiveRequests_sendDifferentCorrelationHeaders() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try await sut.fetchVessels()
        _ = try await sut.fetchVessels()

        let ids = httpClient.receivedRequests.compactMap { $0.value(forHTTPHeaderField: "x-cdp-request-id") }
        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1])
    }

    // MARK: Fetch-all invariant — no query parameters are ever sent

    func test_everyCollectionRequest_sendsNoQueryParameters() async throws {
        // The backend treats any query key other than `view` as narrowing the request, silently
        // engaging pagination at its `defaultLimit` (see ADR-0018 addendum "Fetch-all, no query
        // parameters"). The app relies on every request having zero query parameters so it always
        // gets the full collection back. The stub always returns the vessels-collection fixture
        // regardless of route, so `fetchVessel`/`fetchManifest` are expected to fail to decode —
        // this test only cares about the *requests sent*, not successful decoding.
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: loadVesselsFixture())
        let sut = RemoteReferenceDataClient(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: nil)
        )

        _ = try? await sut.fetchVessels()
        _ = try? await sut.fetchVessel(id: vesselId)
        _ = try? await sut.fetchManifest()

        XCTAssertEqual(httpClient.receivedRequests.count, 3)
        for request in httpClient.receivedRequests {
            XCTAssertNil(request.url?.query, "Request to \(request.url?.absoluteString ?? "?") must carry no query string")
        }
    }
}
