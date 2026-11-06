import CoreLocation
import Foundation

/// Finds the statistical (sub)areas nearest to a given port, for the "Select the statistical sub
/// area…" screen reached from the catch-location map's "Other" button (see
/// `CatchLocationNearestAreasViewModel`).
nonisolated protocol NearestSubrectangleProviding: Sendable {
    /// Returns up to `limit` selectable subrectangle codes nearest to `coordinate`, nearest first.
    func nearestCodes(to coordinate: PortCoordinate, limit: Int) async throws -> [String]
}

/// Nearest-area lookup backed by the same bundled, precomputed subrectangle layer
/// `OfflineMapView`/`BundledSubrectangleSearchProvider` use — static data shipped in the app, so
/// this works fully offline with no network call (see ADR-0004 for the provider seam this stands
/// behind).
nonisolated struct BundledNearestSubrectangleProvider: NearestSubrectangleProviding {

    /// Pure input to `rankedCodes(from:around:limit:)`: a selectable subrectangle's code and the
    /// coordinate used to measure its distance from the port (its label coordinate — the polygon's
    /// own bounding-rect centre, see `SubrectangleOverlay.labelCoordinate` — never the shared,
    /// parent-rectangle `stat_x`/`stat_y`, which would collapse sibling subrectangles onto the
    /// same distance).
    struct Candidate {
        let subCode: String
        let coordinate: CLLocationCoordinate2D
    }

    private let candidates: [Candidate]

    /// - Parameter candidates: The searchable set. Defaults to the real bundled, precomputed
    ///   subrectangle layer's sea-overlapping overlays (mirrors
    ///   `BundledSubrectangleSearchProvider`); pass an explicit list in tests.
    init(candidates: [Candidate] = BundledNearestSubrectangleProvider.loadBundledCandidates()) {
        self.candidates = candidates
    }

    func nearestCodes(to coordinate: PortCoordinate, limit: Int) async throws -> [String] {
        Self.rankedCodes(from: candidates, around: coordinate, limit: limit)
    }

    /// Pure ranking, exposed for unit testing without touching the app bundle: nearest first (by
    /// great-circle distance), ties broken alphabetically by code, deduplicated, truncated to
    /// `limit`. A `limit <= 0` returns an empty list rather than every candidate.
    static func rankedCodes(from candidates: [Candidate], around coordinate: PortCoordinate, limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var distanceByCode: [String: CLLocationDistance] = [:]
        for candidate in candidates where distanceByCode[candidate.subCode] == nil {
            let candidateLocation = CLLocation(
                latitude: candidate.coordinate.latitude,
                longitude: candidate.coordinate.longitude
            )
            distanceByCode[candidate.subCode] = origin.distance(from: candidateLocation)
        }

        return distanceByCode
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value < rhs.value
            }
            .prefix(limit)
            .map(\.key)
    }

    /// Loads the bundled, precomputed subrectangle layer and derives the candidate list. Falls
    /// back to an empty list if the resource is missing/malformed — callers already treat an empty
    /// list as "no nearby areas" (only "Other" shown) rather than a fatal error, consistent with
    /// the rest of the offline-first map loading.
    static func loadBundledCandidates(bundle: Bundle = .main) -> [Candidate] {
        guard let result = try? PrecomputedMapLoader.loadBundledSubrectangles(bundle: bundle) else { return [] }
        return result.selectableOverlays.map { Candidate(subCode: $0.subCode, coordinate: $0.labelCoordinate) }
    }
}
