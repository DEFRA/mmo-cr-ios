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

/// A gear's category, nested inside a `?view=mobile` gear item (see ADR-0018 addendum "gears
/// dataset"). All three fields are plain text so a category the app hasn't seen yet still decodes.
nonisolated struct GearCategoryDTO: Decodable, Sendable {
    let id: String?
    let code: String?
    let name: String?
}

/// One entry in a `?view=mobile` gears response's top-level `measurements` catalogue — the
/// labelled definition a gear's `requiredMeasurementIds`/`variableMeasurementIds` resolve against
/// (see `GearsMobileResponseDTO`). `kind` and `unit` are kept as plain text (not an enum) so a
/// value the app hasn't seen yet still decodes rather than failing the whole response.
nonisolated struct GearMeasurementDefinitionDTO: Decodable, Sendable {
    let id: String
    let code: String?
    let label: String
    let kind: String?
    let unit: String?
    let minimumValue: Double?
    let maximumValue: Double?
}

/// Wire shape for a single item in the `gears` dataset's `?view=mobile` response (see ADR-0018
/// addendum "gears dataset"). Only `id`, `code` and `name` are required; every other field may be
/// omitted or `null` to match the real API. Deliberately **not** the canonical-view shape — the
/// mobile view is the one this connector requests for `gears`, because only it carries the
/// `measurements` catalogue (see `GearsMobileResponseDTO`) needed to turn
/// `requiredMeasurementIds`/`variableMeasurementIds` into labelled `GearMeasurement`s.
nonisolated struct GearMobileDTO: Decodable, Sendable {
    let id: String
    let code: String
    let name: String
    let category: GearCategoryDTO?
    let pairFishing: Bool?
    let requiredMeasurementIds: [String]?
    let variableMeasurementIds: [String]?
}

/// Response envelope for `GET {baseURL}/api/v1/reference-data/gears?view=mobile` (see ADR-0018
/// addendum "gears dataset"). **Not** `ReferenceDataEnvelope<GearMobileDTO>`: the mobile gears
/// response additionally carries a top-level `measurements` catalogue that the shared envelope
/// has no field for, so `gears` gets its own response type rather than forcing the shared shape.
nonisolated struct GearsMobileResponseDTO: Decodable, Sendable {
    let dataset: String
    let collectionId: String
    let schemaVersion: String
    let version: String
    let view: String
    let total: Int
    let items: [GearMobileDTO]
    /// The labelled measurement definitions every item's measurement ids resolve against.
    /// Optional (not a non-optional `[]` default) so a response that omits it entirely still
    /// decodes — every item then maps with empty measurement lists (see
    /// `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)`).
    let measurements: [GearMeasurementDefinitionDTO]?
}

/// One link between a gear and a measurement in the **canonical** (default) view's
/// `applicableCharacteristics` array (see ADR-0024 "Gears from two requests"). `fixed` is the
/// field this connector treats as "required, captured once when the gear is added to
/// favourites" — the live API's own `required` flag is `false` on every link, so it is not
/// modelled here at all (ADR-0024 records this as a backend-data oddity, not a connector bug).
/// `vesselLengthApplicability` lists the vessel-length bands (e.g. `"under-10m"`, `"10-to-12m"`,
/// `"over-12m"`) this measurement applies to; the app currently only asks for the `"under-10m"`
/// band (ADR-0024 "Vessel-length scope").
nonisolated struct GearCharacteristicDTO: Decodable, Sendable {
    let id: String?
    let characteristicId: String
    let fixed: Bool
    let required: Bool?
    let vesselLengthApplicability: [String]?
}

/// Wire shape for a single item in the `gears` dataset's **canonical** (default, no `view`
/// query parameter) response — see ADR-0024 "Gears from two requests". Fetched *alongside* the
/// `?view=mobile` response (`GearMobileDTO`) because only this canonical shape carries
/// `applicableCharacteristics.fixed`, the required/per-trip split this connector relies on.
nonisolated struct GearCanonicalDTO: Decodable, Sendable {
    let id: String
    let code: String
    let name: String
    let categoryId: String?
    let pairFishing: Bool?
    let applicableCharacteristics: [GearCharacteristicDTO]?
    let active: Bool?
}
