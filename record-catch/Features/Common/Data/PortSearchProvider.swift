import CoreLocation
import Foundation

/// Supplies the ports a user can search for on the Add-port screen.
///
/// API-shaped: `async throws` so a future real Ports API can swap in without changing
/// `AddPortViewModel` or its tests (see ADR-0004). Backed by the real bundled `ports.geojson`
/// list (see `BundledPortSearchProvider`) pending a real Ports API.
nonisolated protocol PortSearchProviding: Sendable {
    /// Ports whose name contains `query` (case-insensitive), or an empty list when `query` is
    /// shorter than `minimumCharacters`.
    func searchPorts(matching query: String) async throws -> [PortOption]

    /// The full set of ports, used to seed a locally-filtering search field. A real API-backed
    /// implementation may page or cache; this returns its loaded list.
    func allPorts() async throws -> [PortOption]
}

/// Port search backed by the real, bundled `ports.geojson` resource (the same data the offline
/// map's `PortLoader` renders — see ADR-0004 for the provider seam this stands behind).
///
/// The bundled file is static and ships in the app, so there is no need for this to be async or
/// networked: the deduplicated, sorted list is loaded once at construction. `coordinate` is
/// populated on every returned `PortOption` from the GeoJSON geometry, for later use (e.g.
/// showing the selected port on a map).
nonisolated struct BundledPortSearchProvider: PortSearchProviding {

    /// Minimum characters before any results are returned (matches the search field's default).
    let minimumCharacters: Int
    private let ports: [PortOption]

    /// - Parameter ports: The searchable list. Defaults to the real bundled `ports.geojson` list
    ///   (deduplicated by port code, sorted alphabetically); pass an explicit list in tests.
    init(minimumCharacters: Int = 2, ports: [PortOption] = BundledPortSearchProvider.loadBundledPorts()) {
        self.minimumCharacters = minimumCharacters
        self.ports = ports
    }

    /// Convenience for tests/demos that only care about names (no known coordinate).
    init(minimumCharacters: Int = 2, names: [String]) {
        self.init(minimumCharacters: minimumCharacters, ports: names.map { PortOption(name: $0) })
    }

    func searchPorts(matching query: String) async throws -> [PortOption] {
        Self.filtered(query: query, minimumCharacters: minimumCharacters, ports: ports)
    }

    func allPorts() async throws -> [PortOption] {
        ports
    }

    /// Pure filtering, exposed for unit testing without awaiting the async surface.
    static func filtered(query: String, minimumCharacters: Int, ports: [PortOption]) -> [PortOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else { return [] }
        return ports.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Loads and parses the bundled `ports.geojson` resource into search options. Falls back to an
    /// empty list if the resource is missing/malformed — callers (`AddPortViewModel`) already treat
    /// an empty list as "no matches" rather than a fatal error, consistent with the rest of the
    /// offline-first ports/map loading.
    static func loadBundledPorts(bundle: Bundle = .main) -> [PortOption] {
        guard let markers = try? PortLoader.loadBundled(bundle: bundle) else { return [] }
        return options(from: markers)
    }

    /// Pure mapping from parsed GeoJSON port markers to search options, exposed for unit testing
    /// without touching the app bundle.
    ///
    /// A small number of ports appear more than once in the source `ports.geojson` (repeated,
    /// identical features) — these are collapsed to a single option, keyed by the stable
    /// `port_code`, keeping the first occurrence. The result is sorted alphabetically by name to
    /// match the previous static list's ordering.
    static func options(from markers: [PortMarker]) -> [PortOption] {
        var seenCodes = Set<Double>()
        var deduplicated: [PortMarker] = []
        for marker in markers where !seenCodes.contains(marker.portCode) {
            seenCodes.insert(marker.portCode)
            deduplicated.append(marker)
        }

        return deduplicated
            .map { marker in
                PortOption(
                    id: String(format: "%.0f", marker.portCode),
                    name: marker.name,
                    coordinate: PortCoordinate(latitude: marker.coordinate.latitude, longitude: marker.coordinate.longitude)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
