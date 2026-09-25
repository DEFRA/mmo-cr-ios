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
