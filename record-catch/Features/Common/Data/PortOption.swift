import Foundation

/// A port's location, carried alongside its `PortOption` for later use (e.g. showing the port on
/// a map, or distance calculations) once a catch record needs it.
///
/// A plain, MapKit-independent `Double` pair — deliberately not `CLLocationCoordinate2D` — so
/// `PortOption` stays trivially `Hashable`/`Codable`/`Sendable` without importing CoreLocation.
/// Mirrors the source GeoJSON's WGS84 degrees (see `RawGeoJSONGeometry`).
nonisolated struct PortCoordinate: Hashable, Sendable, Codable {
    let latitude: Double
    let longitude: Double
}

/// A port the user can search for and save as a favourite.
///
/// API-shaped value type (see ADR-0004). `id` is stable so a real API-backed provider can supply
/// server identifiers without changing call sites; `name` is the display string. `coordinate` is
/// populated for ports sourced from the real bundled `ports.geojson` list (see
/// `BundledPortSearchProvider`); it's `nil` for hand-built test/demo values that have no location.
///
/// Explicitly `nonisolated` so it can be constructed and read from any actor context (the stubbed
/// providers run off the main actor); a plain `Sendable` value type has no isolation needs.
nonisolated struct PortOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let coordinate: PortCoordinate?

    /// Convenience for hand-built/test values, where the name is also the stable identifier and
    /// there is no known location.
    init(name: String, coordinate: PortCoordinate? = nil) {
        self.id = name
        self.name = name
        self.coordinate = coordinate
    }

    init(id: String, name: String, coordinate: PortCoordinate? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
    }
}
