//
//  ReferenceDataValidator.swift
//  record-catch
//
//  Pure validation rules applied to a reference-data response *before* it is allowed to replace
//  the on-device snapshot (see ADR-0024 "Validation"). Deliberately side-effect-free and
//  `nonisolated` so every rule is unit-testable without a network call or a `ModelContext` — one
//  failing check throws `ReferenceDataValidationError` and `ReferenceDataSyncService` keeps the
//  existing snapshot for that dataset (strict, all-or-nothing per dataset).
//

import Foundation

nonisolated enum ReferenceDataValidator {

    /// Any response over this size is rejected outright (see ADR-0024 "Validation") — a
    /// defence-in-depth cap, since every dataset today is a few hundred items at most.
    static let maximumResponseSizeBytes = 10 * 1024 * 1024

    /// Rejects a response whose raw body exceeds `maximumResponseSizeBytes`.
    static func validateResponseSize(dataset: String, sizeBytes: Int) throws {
        guard sizeBytes <= maximumResponseSizeBytes else {
            throw ReferenceDataValidationError.responseTooLarge(dataset: dataset, sizeBytes: sizeBytes)
        }
    }

    /// Shared count-level checks applied to every mapped dataset (`vessels`/`species`/`ports`/
    /// `gears`) before it replaces the on-device snapshot: the mapped item list isn't empty, and —
    /// when the triggering manifest entry supplied an `itemCount` — it matches the actual count.
    ///
    /// Deliberately operates on the already-mapped domain array (`[PortOption]` etc.), not the raw
    /// wire envelope: `ReferenceDataFetching` only exposes mapped results (see ADR-0018), so a
    /// stricter per-response `version`/`collectionId` cross-check against the manifest entry that
    /// triggered the fetch is out of reach here without changing that protocol's shape for every
    /// call site. `gears` gets that stronger cross-check independently, between its own two raw
    /// responses, in `RemoteReferenceDataClient.fetchGears()` (see ADR-0024 "Gears from two
    /// requests").
    static func validateItemCount(
        dataset: String,
        itemCount: Int,
        manifestEntry: ReferenceDataManifestEntry?
    ) throws {
        guard itemCount > 0 else {
            throw ReferenceDataValidationError.emptyDataset(dataset: dataset)
        }
        guard let expected = manifestEntry?.itemCount else { return }
        guard expected == itemCount else {
            throw ReferenceDataValidationError.itemCountMismatch(
                dataset: dataset, expected: expected, actual: itemCount
            )
        }
    }

    /// Rejects a dataset containing two items with the same identifier.
    static func validateUniqueIdentifiers(dataset: String, identifiers: [String]) throws {
        var seen = Set<String>()
        for identifier in identifiers where !seen.insert(identifier).inserted {
            throw ReferenceDataValidationError.duplicateIdentifier(dataset: dataset, identifier: identifier)
        }
    }

    /// Dataset-specific sanity checks for `ports`: a unique, non-empty `id`; a non-blank `name`;
    /// a `coordinate` (when present) within valid WGS84 latitude/longitude ranges.
    static func validatePorts(_ ports: [PortOption]) throws {
        try validateUniqueIdentifiers(dataset: "ports", identifiers: ports.map(\.id))
        for port in ports {
            guard !port.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "ports", identifier: port.id, reason: "blank id"
                )
            }
            guard !port.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "ports", identifier: port.id, reason: "blank name"
                )
            }
            if let coordinate = port.coordinate {
                guard
                    (-90...90).contains(coordinate.latitude),
                    (-180...180).contains(coordinate.longitude)
                else {
                    throw ReferenceDataValidationError.invalidItem(
                        dataset: "ports",
                        identifier: port.id,
                        reason: "coordinate out of range"
                    )
                }
            }
        }
    }

    /// Dataset-specific sanity checks for `species`: a unique, non-empty `id`; a non-blank `name`
    /// (already guaranteed by `SpeciesOption.init(dto:)`'s fallback chain, but checked here too so
    /// a future change to that fallback can't silently regress this invariant).
    static func validateSpecies(_ species: [SpeciesOption]) throws {
        try validateUniqueIdentifiers(dataset: "species", identifiers: species.map(\.id))
        for item in species {
            guard !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "species", identifier: item.id, reason: "blank id"
                )
            }
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "species", identifier: item.id, reason: "blank name"
                )
            }
        }
    }

    /// Dataset-specific sanity checks for `vessels`: a unique, non-empty `id`; a non-blank `name`;
    /// `lengthOverallMetres` (when present) must be a positive value — a vessel's length is used
    /// to decide its length band (see `GearOption.currentVesselLengthBand`), so a zero/negative
    /// value would be a data error, not a legitimate absence.
    static func validateVessels(_ vessels: [VesselOption]) throws {
        try validateUniqueIdentifiers(dataset: "vessels", identifiers: vessels.map(\.id))
        for vessel in vessels {
            guard !vessel.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "vessels", identifier: vessel.id, reason: "blank id"
                )
            }
            guard !vessel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "vessels", identifier: vessel.id, reason: "blank name"
                )
            }
            if let length = vessel.lengthOverallMetres, length <= 0 {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "vessels",
                    identifier: vessel.id,
                    reason: "non-positive lengthOverallMetres"
                )
            }
        }
    }

    /// Dataset-specific sanity checks for `gears`: a unique, non-empty `id` (the FAO gear code —
    /// see `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)`), a non-blank
    /// `name`, and every measurement (required or variable) has a non-blank label. The
    /// required/per-trip join itself (including the unresolved-measurement-id check) already
    /// happens in `RemoteReferenceDataClient.fetchGears()`, since it needs the two raw responses
    /// this validator never sees — this only re-checks the *resulting* `GearOption`s are sane.
    static func validateGears(_ gears: [GearOption]) throws {
        try validateUniqueIdentifiers(dataset: "gears", identifiers: gears.map(\.id))
        for gear in gears {
            guard !gear.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "gears", identifier: gear.id, reason: "blank id"
                )
            }
            guard !gear.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "gears", identifier: gear.id, reason: "blank name"
                )
            }
            for measurement in gear.requiredMeasurements + gear.variableMeasurements
            where measurement.labelKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ReferenceDataValidationError.invalidItem(
                    dataset: "gears",
                    identifier: gear.id,
                    reason: "blank measurement label"
                )
            }
        }
    }

    /// Sanity checks for a raw blob dataset (`map-land`/`map-statistical-areas` — see ADR-0024
    /// "Map data"): non-empty, within the shared size cap, and well-formed JSON (GeoJSON is JSON,
    /// so this is a cheap defence against a truncated or unparsable response slipping through as a
    /// 2xx). No deeper GeoJSON-specific validation is performed: this connector stores the blob
    /// opaquely and does not parse or precompute it — that remains explicitly out of scope (see
    /// ADR-0024 "Map data").
    static func validateBlob(dataset: String, data: Data) throws {
        guard !data.isEmpty else {
            throw ReferenceDataValidationError.emptyDataset(dataset: dataset)
        }
        try validateResponseSize(dataset: dataset, sizeBytes: data.count)
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw ReferenceDataValidationError.malformedBlob(dataset: dataset)
        }
    }
}
