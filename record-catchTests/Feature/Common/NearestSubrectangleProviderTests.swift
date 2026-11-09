import CoreLocation
import XCTest
@testable import record_catch

final class NearestSubrectangleProviderTests: XCTestCase {

    private typealias Candidate = BundledNearestSubrectangleProvider.Candidate

    private let plymouth = PortCoordinate(latitude: 50.3660, longitude: -4.1427)

    // MARK: - nearestCodes (instance behaviour)

    func test_nearestCodes_returnsProviderRanking() async throws {
        let candidates = [
            Candidate(subCode: "38E84", coordinate: CLLocationCoordinate2D(latitude: 50.40, longitude: -4.10)),
            Candidate(subCode: "38E86", coordinate: CLLocationCoordinate2D(latitude: 51.00, longitude: -4.00))
        ]
        let sut = BundledNearestSubrectangleProvider(candidates: candidates)

        let codes = try await sut.nearestCodes(to: plymouth, limit: 9)

        XCTAssertEqual(codes, ["38E84", "38E86"])
    }

    // MARK: - Pure ranking (rankedCodes(from:around:limit:))

    func test_rankedCodes_ordersNearestFirst() {
        let near = Candidate(subCode: "NEAR", coordinate: CLLocationCoordinate2D(latitude: 50.40, longitude: -4.10))
        let far = Candidate(subCode: "FAR", coordinate: CLLocationCoordinate2D(latitude: 55.00, longitude: -3.00))

        let codes = BundledNearestSubrectangleProvider.rankedCodes(from: [far, near], around: plymouth, limit: 9)

        XCTAssertEqual(codes, ["NEAR", "FAR"])
    }

    func test_rankedCodes_appliesLimit() {
        let candidates = (0..<20).map { index in
            Candidate(
                subCode: "C\(String(format: "%02d", index))",
                coordinate: CLLocationCoordinate2D(latitude: 50.0 + Double(index) * 0.1, longitude: -4.0)
            )
        }

        let codes = BundledNearestSubrectangleProvider.rankedCodes(from: candidates, around: plymouth, limit: 9)

        XCTAssertEqual(codes.count, 9)
    }

    func test_rankedCodes_withZeroLimit_returnsEmpty() {
        let candidate = Candidate(subCode: "38E84", coordinate: CLLocationCoordinate2D(latitude: 50.40, longitude: -4.10))

        XCTAssertTrue(BundledNearestSubrectangleProvider.rankedCodes(from: [candidate], around: plymouth, limit: 0).isEmpty)
    }

    func test_rankedCodes_withNoCandidates_returnsEmpty() {
        XCTAssertTrue(BundledNearestSubrectangleProvider.rankedCodes(from: [], around: plymouth, limit: 9).isEmpty)
    }

    func test_rankedCodes_deduplicatesByCode_keepingFirstDistance() {
        // Two candidates sharing a code (mirrors how `BundledSubrectangleSearchProvider`
        // deduplicates sea-overlapping overlays by `subCode`) should contribute a single ranked
        // entry, not two.
        let candidates = [
            Candidate(subCode: "38E84", coordinate: CLLocationCoordinate2D(latitude: 50.40, longitude: -4.10)),
            Candidate(subCode: "38E84", coordinate: CLLocationCoordinate2D(latitude: 55.00, longitude: -3.00))
        ]

        let codes = BundledNearestSubrectangleProvider.rankedCodes(from: candidates, around: plymouth, limit: 9)

        XCTAssertEqual(codes, ["38E84"])
    }

    func test_rankedCodes_breaksExactTiesAlphabeticallyByCode() {
        // Both candidates sit at the exact same coordinate, so distance alone can't order them.
        let sameCoordinate = CLLocationCoordinate2D(latitude: 50.40, longitude: -4.10)
        let candidates = [
            Candidate(subCode: "38E96", coordinate: sameCoordinate),
            Candidate(subCode: "38E84", coordinate: sameCoordinate)
        ]

        let codes = BundledNearestSubrectangleProvider.rankedCodes(from: candidates, around: plymouth, limit: 9)

        XCTAssertEqual(codes, ["38E84", "38E96"])
    }

    // MARK: - Bundled resource loading

    func test_loadBundledCandidates_parsesTheRealBundledPrecomputedResource() {
        let testBundle = Bundle(for: NearestSubrectangleProviderTests.self)

        let candidates = BundledNearestSubrectangleProvider.loadBundledCandidates(bundle: testBundle)

        XCTAssertFalse(candidates.isEmpty)
    }

    func test_loadBundledCandidates_whenResourceMissing_returnsEmptyList() {
        // The Foundation framework bundle certainly doesn't ship the precomputed subrectangle
        // resource — exercises the "resource not found" fallback without touching the app bundle.
        let unrelatedBundle = Bundle(for: NSObject.self)

        let candidates = BundledNearestSubrectangleProvider.loadBundledCandidates(bundle: unrelatedBundle)

        XCTAssertTrue(candidates.isEmpty)
    }
}
