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
/// `BundledPortSearchProvider`) or the reference-data API's `ports` dataset (see ADR-0018
/// addendum); it's `nil` for hand-built test/demo values that have no location, and for the small
/// number of reference-data ports the API itself has no coordinate for.
///
/// `code`, `countryCode` and `isActive` are only ever populated by `init(dto:)`, mapping the
/// reference-data API's `ports` dataset (see `PortDTO`) — they are `nil` for every other source
/// (bundled `ports.geojson`, hand-built test/demo values) and are **deliberately optional types**
/// (not a non-optional `Bool` with a default) so previously-persisted `CatchRecordDraft` JSON that
/// predates these fields still decodes via the synthesized `Codable` conformance — see ADR-0014 for
/// the offline-first draft store this type is persisted in.
///
/// Explicitly `nonisolated` so it can be constructed and read from any actor context (the stubbed
/// providers run off the main actor); a plain `Sendable` value type has no isolation needs.
nonisolated struct PortOption: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let coordinate: PortCoordinate?
    /// The reference-data API's own code for this port (e.g. `"GBABD"`), when sourced from
    /// `init(dto:)`. `nil` for every other source.
    let code: String?
    /// ISO 3166-1 alpha-3 country code for this port, when sourced from `init(dto:)`. `nil` for
    /// every other source.
    let countryCode: String?
    /// Whether this port is currently active in the reference-data catalogue, when sourced from
    /// `init(dto:)`. `nil` for every other source; treat `nil` as active (matches the API's own
    /// observed default — see `init(dto:)`).
    let isActive: Bool?

    /// Convenience for hand-built/test values, where the name is also the stable identifier and
    /// there is no known location.
    init(name: String, coordinate: PortCoordinate? = nil) {
        self.init(id: name, name: name, coordinate: coordinate)
    }

    init(
        id: String,
        name: String,
        coordinate: PortCoordinate? = nil,
        code: String? = nil,
        countryCode: String? = nil,
        isActive: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.code = code
        self.countryCode = countryCode
        self.isActive = isActive
    }

    /// Maps the wire DTO into the domain type (see ADR-0018 addendum — the `ports` dataset).
    /// `coordinate` is copied across directly since `PortDTO.coordinate` already decodes into this
    /// type's own `PortCoordinate`.
    init(dto: PortDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            coordinate: dto.coordinate,
            code: dto.code,
            countryCode: dto.countryCode,
            isActive: dto.active
        )
    }
}
