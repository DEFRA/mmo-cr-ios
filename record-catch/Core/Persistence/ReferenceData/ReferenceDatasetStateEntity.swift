//
//  ReferenceDatasetStateEntity.swift
//  record-catch
//
//  Tracks the locally-synced version of one reference-data dataset (ports/species/gears/vessels)
//  so `ReferenceDataSyncService` can tell "unchanged, skip the fetch" from "the manifest moved on,
//  refetch" without re-downloading every dataset on every launch (see ADR-0024 "Manifest-driven
//  change detection").
//
//  One row per dataset (`dataset` is unique) — there is no history kept; each sync either leaves
//  this row untouched (unchanged) or replaces it atomically alongside the dataset's
//  `ReferenceItemEntity` rows (see `ReferenceDataStore.replace(dataset:items:state:)`).
//

import Foundation
import SwiftData

/// The locally-synced state of one reference dataset. Not personal data — reference data is kept
/// across sign-out (see ADR-0024 "Sign-out"), unlike `ServerCatchRecordEntity`-style data would be.
@Model
final class ReferenceDatasetStateEntity {
    @Attribute(.unique) var dataset: String
    var collectionId: String
    var version: String
    var schemaVersion: String
    /// The manifest's `itemCount` for this dataset at the time of this sync, when the manifest
    /// supplied one (see `ReferenceDataManifestEntry.itemCount`, `Int?` since the live manifest's
    /// map entries omit it — not relevant here, since every dataset this store tracks always
    /// reports one, but kept optional for symmetry with the wire type rather than force-unwrapping
    /// at the call site).
    var itemCount: Int?
    var lastModified: String
    /// When this device last successfully synced this dataset (distinct from `lastModified`, the
    /// server's own timestamp for the data itself).
    var syncedAt: Date
    /// This app's own payload-format version for the dataset (see
    /// `ReferenceDataSyncService.payloadFormatVersion`). Bumped whenever the on-device JSON shape
    /// (`PortOption`/`SpeciesOption`/`GearOption`/`VesselOption`) changes in a way that isn't
    /// forward/backward compatible, forcing a refetch even when the server-side `version` is
    /// unchanged — this connector does not support schema migrations (ADR-0024 "No migrations").
    var payloadFormatVersion: Int

    init(
        dataset: String,
        collectionId: String,
        version: String,
        schemaVersion: String,
        itemCount: Int?,
        lastModified: String,
        syncedAt: Date,
        payloadFormatVersion: Int
    ) {
        self.dataset = dataset
        self.collectionId = collectionId
        self.version = version
        self.schemaVersion = schemaVersion
        self.itemCount = itemCount
        self.lastModified = lastModified
        self.syncedAt = syncedAt
        self.payloadFormatVersion = payloadFormatVersion
    }
}
