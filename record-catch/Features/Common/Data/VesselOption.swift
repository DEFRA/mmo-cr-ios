//
//  VesselOption.swift
//  record-catch
//
//  A vessel from the reference-data API's `vessels` dataset (see ADR-0018). API-shaped value type
//  mirroring `PortOption`/`GearOption` (see ADR-0004) — a stable `id`, plus the fields the app
//  displays. Unlike `PortOption`, this is the connector's first domain type mapped from a *real*
//  network response (`VesselDTO`) rather than a stub/bundled source.
//
//  Carries every field the API's canonical view exposes (see ADR-0018's correction note on why
//  the connector uses the canonical view rather than `?view=mobile`), flattening the wire DTO's
//  nested `identifiers` object into top-level properties for convenience at call sites.
//
//  This type is intentionally not wired into `VesselProviding`/`StaticVesselProvider` or any view
//  model in this change — see ADR-0018 for the connector-only scope of this PR.
//

import Foundation

/// A vessel the user can select, sourced from the reference-data API's canonical view.
nonisolated struct VesselOption: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    /// Always populated: the API's own `namePln` when supplied, otherwise derived from
    /// `name`/`externalMark` (see `init(dto:)`).
    let displayName: String
    let cfr: String?
    let uvi: String?
    let mmsi: String?
    let ircs: String?
    let externalMark: String?
    let registrationNumber: String?
    let typeCode: String?
    let registrationCountryCode: String?
    let lengthOverallMetres: Double?
    let status: String?
    let activeFrom: String?
    let activeTo: String?

    /// Maps the wire DTO into the domain type, flattening `identifiers` and deriving
    /// `displayName` when the API omits `namePln`: `"NAME EXTERNAL_MARK"` when an `externalMark`
    /// is present, falling back to `name` alone otherwise.
    init(dto: VesselDTO) {
        self.id = dto.id
        self.name = dto.name
        self.cfr = dto.identifiers?.cfr
        self.uvi = dto.identifiers?.uvi
        self.mmsi = dto.identifiers?.mmsi
        self.ircs = dto.identifiers?.ircs
        self.externalMark = dto.identifiers?.externalMark
        self.registrationNumber = dto.identifiers?.registrationNumber
        self.typeCode = dto.typeCode
        self.registrationCountryCode = dto.registrationCountryCode
        self.lengthOverallMetres = dto.lengthOverallMetres
        self.status = dto.status
        self.activeFrom = dto.activeFrom
        self.activeTo = dto.activeTo
        if let namePln = dto.namePln, !namePln.isEmpty {
            self.displayName = namePln
        } else if let mark = dto.identifiers?.externalMark, !mark.isEmpty {
            self.displayName = [dto.name, mark].joined(separator: " ")
        } else {
            self.displayName = dto.name
        }
    }

    /// Convenience for hand-built/test values. Only the fields exercised by hand-built call sites
    /// are exposed here (see swift-swiftui.instructions.md on preferring fewer parameters); every
    /// other field is reachable only via `init(dto:)`, which the real API response always
    /// populates.
    init(
        id: String,
        name: String,
        displayName: String? = nil,
        externalMark: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cfr = nil
        self.uvi = nil
        self.mmsi = nil
        self.ircs = nil
        self.externalMark = externalMark
        self.registrationNumber = nil
        self.typeCode = nil
        self.registrationCountryCode = nil
        self.lengthOverallMetres = nil
        self.status = nil
        self.activeFrom = nil
        self.activeTo = nil
        self.displayName = Self.derivedDisplayName(name: name, preferred: displayName, externalMark: externalMark)
    }

    /// Shared display-name derivation rule used by both initializers: the API's own `namePln`/the
    /// caller-supplied `displayName` wins when non-empty, then `"NAME EXTERNAL_MARK"` when an
    /// `externalMark` is present, falling back to `name` alone.
    private static func derivedDisplayName(name: String, preferred: String?, externalMark: String?) -> String {
        if let preferred, !preferred.isEmpty {
            return preferred
        } else if let externalMark, !externalMark.isEmpty {
            return [name, externalMark].joined(separator: " ")
        } else {
            return name
        }
    }
}
