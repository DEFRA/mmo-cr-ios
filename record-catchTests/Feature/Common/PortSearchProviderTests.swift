import CoreLocation
import XCTest
@testable import record_catch

final class PortSearchProviderTests: XCTestCase {

    func test_searchPorts_belowMinimumCharacters_returnsEmpty() async throws {
        let sut = BundledPortSearchProvider(minimumCharacters: 2, names: ["Aberdeen"])

        let results = try await sut.searchPorts(matching: "a")

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchPorts_matchesCaseInsensitively() async throws {
        let sut = BundledPortSearchProvider(names: ["Aberdeen", "Hull"])

        let results = try await sut.searchPorts(matching: "aber")

        XCTAssertEqual(results.map(\.name), ["Aberdeen"])
    }

    func test_searchPorts_returnsAllMatches() async throws {
        let sut = BundledPortSearchProvider(names: ["Brixham", "Shoreham", "Hull"])

        let results = try await sut.searchPorts(matching: "ham")

        XCTAssertEqual(results.map(\.name), ["Brixham", "Shoreham"])
    }

    func test_searchPorts_trimsWhitespace() async throws {
        let sut = BundledPortSearchProvider(names: ["Aberdeen"])

        let results = try await sut.searchPorts(matching: "  aber  ")

        XCTAssertEqual(results.map(\.name), ["Aberdeen"])
    }

    func test_allPorts_returnsFullProvidedList() async throws {
        let sut = BundledPortSearchProvider(names: ["Hull", "Newlyn"])

        let results = try await sut.allPorts()

        XCTAssertEqual(results.map(\.name), ["Hull", "Newlyn"])
    }

    func test_filtered_isPureAndDeterministic() {
        let ports = [PortOption(name: "Hull"), PortOption(name: "Newlyn")]

        XCTAssertEqual(
            BundledPortSearchProvider.filtered(query: "ne", minimumCharacters: 2, ports: ports).map(\.name),
            ["Newlyn"]
        )
        XCTAssertTrue(
            BundledPortSearchProvider.filtered(query: "n", minimumCharacters: 2, ports: ports).isEmpty
        )
    }

    // MARK: - GeoJSON-backed loading (see ADR-0004 / PortLoader)
    //
    // `PortMarker`/`PortLoader` are compiled into both the app target and this test target (see
    // the pbxproj's synchronized-group membership exceptions, used so `PortLoaderTests` can load
    // the bundled resource directly). That means the bare name `PortMarker` here would resolve to
    // this test target's own local copy rather than the `record_catch` module's type that
    // `BundledPortSearchProvider.options(from:)` expects — qualify explicitly to avoid that clash.

    func test_options_mapsMarkerToOptionWithCoordinate() {
        let marker = record_catch.PortMarker(portCode: 1407, name: "Aberdeen", coordinate: .init(latitude: 57.143, longitude: -2.079))

        let options = BundledPortSearchProvider.options(from: [marker])

        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options.first?.id, "1407")
        XCTAssertEqual(options.first?.name, "Aberdeen")
        XCTAssertEqual(options.first?.coordinate?.latitude ?? 0, 57.143, accuracy: 0.0001)
        XCTAssertEqual(options.first?.coordinate?.longitude ?? 0, -2.079, accuracy: 0.0001)
    }

    func test_options_deduplicatesRepeatedFeaturesByPortCode() {
        let markers: [record_catch.PortMarker] = [
            .init(portCode: 1407, name: "Aberdeen", coordinate: .init(latitude: 57.143, longitude: -2.079)),
            .init(portCode: 1407, name: "Aberdeen", coordinate: .init(latitude: 57.143, longitude: -2.079)),
            .init(portCode: 601, name: "Hastings", coordinate: .init(latitude: 50.855, longitude: 0.593))
        ]

        let options = BundledPortSearchProvider.options(from: markers)

        XCTAssertEqual(options.map(\.name), ["Aberdeen", "Hastings"])
    }

    func test_options_sortsAlphabeticallyByName() {
        let markers: [record_catch.PortMarker] = [
            .init(portCode: 601, name: "Hastings", coordinate: .init(latitude: 50.855, longitude: 0.593)),
            .init(portCode: 1407, name: "Aberdeen", coordinate: .init(latitude: 57.143, longitude: -2.079))
        ]

        let options = BundledPortSearchProvider.options(from: markers)

        XCTAssertEqual(options.map(\.name), ["Aberdeen", "Hastings"])
    }

    func test_loadBundledPorts_parsesTheRealBundledPortsResource() {
        let testBundle = Bundle(for: PortSearchProviderTests.self)

        let options = BundledPortSearchProvider.loadBundledPorts(bundle: testBundle)

        // The real "ports.geojson" contains 938 features but some port codes repeat.
        XCTAssertFalse(options.isEmpty)
        XCTAssertEqual(options.count, Set(options.map(\.id)).count, "expected no duplicate port codes")
        XCTAssertTrue(options.contains { $0.name == "Aberdeen" && $0.coordinate != nil })
    }

    func test_loadBundledPorts_whenResourceMissing_returnsEmptyList() {
        // The Foundation framework bundle certainly doesn't ship "ports.geojson" — exercises the
        // "resource not found" fallback without touching the app bundle.
        let unrelatedBundle = Bundle(for: NSObject.self)

        let options = BundledPortSearchProvider.loadBundledPorts(bundle: unrelatedBundle)

        XCTAssertTrue(options.isEmpty)
    }
}

