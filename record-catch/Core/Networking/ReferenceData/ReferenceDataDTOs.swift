//
//  ReferenceDataDTOs.swift
//  record-catch
//
//  Wire-format DTOs for the reference-data API (see ADR-0018 §2). Kept separate from the domain
//  model (`VesselOption`) so a wire-shape change only touches the DTO + its mapping `init`, never
//  call sites.
//
//  Models the **canonical** view (the default view returned when no `view` query parameter is
//  sent — see ADR-0018's correction note). Only `id` and `name` are required; every other field
//  is optional to match the real API, which can omit any of them.
//

import Foundation

/// The `identifiers` object nested inside a canonical-view vessel item.
nonisolated struct VesselIdentifiersDTO: Decodable, Sendable {
    let cfr: String?
    let uvi: String?
    let mmsi: String?
    let ircs: String?
    let externalMark: String?
    let registrationNumber: String?
}

/// Wire shape for a single item in the `vessels` dataset's canonical view.
nonisolated struct VesselDTO: Decodable, Sendable {
    let id: String
    let name: String
    let namePln: String?
    let identifiers: VesselIdentifiersDTO?
    let typeCode: String?
    let registrationCountryCode: String?
    let lengthOverallMetres: Double?
    let status: String?
    let activeFrom: String?
    let activeTo: String?
}

/// A single localised/common name entry nested inside a canonical-view species item's
/// `commonNames`/`localNames` arrays.
nonisolated struct SpeciesNameDTO: Decodable, Sendable {
    let id: String?
    let countryCode: String?
    let name: String
}

/// Wire shape for a single item in the `species` dataset's canonical view. Only `id` is required;
/// every other field is optional to match the real API, which can omit any of them. `name` is
/// deliberately **not** a top-level field on the wire — the API models it as the `commonNames`
/// array — so `SpeciesOption.init(dto:)` derives a single display `name` from it (see ADR-0018
/// addendum).
nonisolated struct SpeciesDTO: Decodable, Sendable {
    let id: String
    let faoCode: String?
    let scientificName: String?
    let commonNames: [SpeciesNameDTO]?
    let localNames: [SpeciesNameDTO]?
    let active: Bool?
}

/// Wire shape for a single item in the `ports` dataset's canonical view (verified against the
/// local backend at `http://localhost:3002`, 624 items). Only `id` and `name` are required; every
/// other field may be omitted or `null` to match the real API. `coordinate` decodes directly into
/// the existing `PortCoordinate` type (see `PortOption.swift`) since the API's `{latitude,
/// longitude}` shape already matches it field-for-field — a handful of items (e.g. "Fowey") have a
/// `null` coordinate.
nonisolated struct PortDTO: Decodable, Sendable {
    let id: String
    let name: String
    let code: String?
    let countryCode: String?
    let coordinate: PortCoordinate?
    let active: Bool?
}
