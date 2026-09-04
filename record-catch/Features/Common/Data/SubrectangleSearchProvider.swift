import Foundation

/// Supplies the statistical subrectangle codes a user can search for on the manual
/// "Enter the statistical sub area…" screen (`CatchLocationManualEntryView`).
///
/// API-shaped: `async throws` so a future real subrectangle-reference API can swap in without
/// changing `CatchLocationManualEntryViewModel` or its tests (mirrors `PortSearchProviding` —
/// see ADR-0004). Backed by the same precomputed, bundled subrectangle layer the offline map
/// itself renders (see `PrecomputedMapLoader`), restricted to the subset that overlaps the sea —
/// the same restriction `OfflineMapView` applies to which subrectangles are selectable, so manual
/// entry can never pick a code the map itself would never allow.
nonisolated protocol SubrectangleSearchProviding: Sendable {
    /// The full set of selectable subrectangle codes, sorted alphabetically, used to seed a
    /// locally-filtering search field. A real API-backed implementation may page or cache; this
    /// returns its loaded list.
    func allCodes() async throws -> [String]
}

/// Subrectangle code search backed by the real, bundled precomputed subrectangle layer (the same
/// data `OfflineMapView`/`PrecomputedMapLoader` render — see ADR-0004 for the provider seam this
/// stands behind).
///
/// The bundled file is static and ships in the app, so there is no need for this to be networked:
/// the deduplicated, sorted list of sea-overlapping subrectangle codes is loaded once at
/// construction.
nonisolated struct BundledSubrectangleSearchProvider: SubrectangleSearchProviding {

    private let codes: [String]

    /// - Parameter codes: The searchable list. Defaults to the real bundled, precomputed
    ///   subrectangle layer's sea-overlapping codes (deduplicated, sorted alphabetically); pass an
    ///   explicit list in tests.
    init(codes: [String] = BundledSubrectangleSearchProvider.loadBundledCodes()) {
        self.codes = codes
    }

    func allCodes() async throws -> [String] {
        codes
    }

    /// Loads the bundled, precomputed subrectangle layer and derives the searchable code list.
    /// Falls back to an empty list if the resource is missing/malformed — callers already treat an
    /// empty list as "no matches" rather than a fatal error, consistent with the rest of the
    /// offline-first map loading.
    static func loadBundledCodes(bundle: Bundle = .main) -> [String] {
        guard let result = try? PrecomputedMapLoader.loadBundledSubrectangles(bundle: bundle) else { return [] }
        return codes(from: result.selectableOverlays)
    }

    /// Pure mapping from parsed subrectangle overlays to sorted, deduplicated search codes,
    /// exposed for unit testing without touching the app bundle.
    static func codes(from overlays: [SubrectangleOverlay]) -> [String] {
        Array(Set(overlays.map(\.subCode))).sorted()
    }
}
