import MapKit
import XCTest
@testable import record_catch

final class SubrectangleSearchProviderTests: XCTestCase {

    // `SubrectangleOverlay`/`SubrectangleProperties` are compiled into both the app target and
    // this test target (mirrors `PortMarker` in `PortSearchProviderTests` — see its comment), so
    // the bare name here would resolve to this test target's own local copy rather than the
    // `record_catch` module's type `BundledSubrectangleSearchProvider.codes(from:)` expects —
    // qualify explicitly to avoid that clash.
    private func makeOverlay(subCode: String) -> record_catch.SubrectangleOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -4.0)
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        return record_catch.SubrectangleOverlay(
            multiPolygon: MKMultiPolygon([polygon]),
            properties: record_catch.SubrectangleProperties(subCode: subCode, icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )
    }

    // MARK: - allCodes

    func test_allCodes_returnsProvidedList() async throws {
        let sut = BundledSubrectangleSearchProvider(codes: ["38E95", "38E84"])

        let codes = try await sut.allCodes()

        XCTAssertEqual(codes, ["38E95", "38E84"])
    }

    // MARK: - Pure mapping (codes(from:))

    func test_codes_sortsAlphabetically() {
        let overlays = [makeOverlay(subCode: "38E96"), makeOverlay(subCode: "38E84")]

        XCTAssertEqual(
            BundledSubrectangleSearchProvider.codes(from: overlays),
            ["38E84", "38E96"]
        )
    }

    func test_codes_deduplicates() {
        let overlays = [makeOverlay(subCode: "38E96"), makeOverlay(subCode: "38E96")]

        XCTAssertEqual(
            BundledSubrectangleSearchProvider.codes(from: overlays),
            ["38E96"]
        )
    }

    func test_codes_emptyForNoOverlays() {
        XCTAssertTrue(BundledSubrectangleSearchProvider.codes(from: []).isEmpty)
    }

    // MARK: - Bundled resource loading

    func test_loadBundledCodes_parsesTheRealBundledPrecomputedResource() {
        let testBundle = Bundle(for: SubrectangleSearchProviderTests.self)

        let codes = BundledSubrectangleSearchProvider.loadBundledCodes(bundle: testBundle)

        XCTAssertFalse(codes.isEmpty)
        XCTAssertEqual(codes, codes.sorted(), "expected the codes to be sorted alphabetically")
        XCTAssertEqual(codes.count, Set(codes).count, "expected no duplicate codes")
    }

    func test_loadBundledCodes_whenResourceMissing_returnsEmptyList() {
        // The Foundation framework bundle certainly doesn't ship the precomputed subrectangle
        // resource — exercises the "resource not found" fallback without touching the app bundle.
        let unrelatedBundle = Bundle(for: NSObject.self)

        let codes = BundledSubrectangleSearchProvider.loadBundledCodes(bundle: unrelatedBundle)

        XCTAssertTrue(codes.isEmpty)
    }
}
