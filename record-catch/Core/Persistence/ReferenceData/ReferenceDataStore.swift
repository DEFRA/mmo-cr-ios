//
//  ReferenceDataStore.swift
//  record-catch
//
//  Background-actor persistence for reference data (see ADR-0024 "SwiftData models" and "Atomic
//  replace"). All writes — and the bulk reads used by the cached search providers — happen off
//  the main actor via `@ModelActor`, so a large dataset replace never blocks the UI thread; the
//  `mainContext` SwiftData gives the environment for free is reserved for UI-facing `@Query`s
//  elsewhere in the app (none of which read this store's entities directly).
//

import Foundation
import SwiftData

/// The reference datasets this store persists. Deliberately separate from the networking layer's
/// `ReferenceDataset` (which also lists `ports`/`species`/`gears`/`vessels`) so persistence code
/// has no dependency on networking types — the two enums are kept in sync by convention and by
/// the sync-service tests, not by sharing a type.
nonisolated enum ReferenceDataKind: String, Sendable, CaseIterable {
    case ports
    case species
    case gears
    case vessels
}

/// The raw-blob reference datasets this store persists (see ADR-0024 "Map data") — unlike
/// `ReferenceDataKind`'s item-shaped datasets, each is a single opaque blob with no per-item
/// identity. `map-ports` is deliberately **not** a case here: per the live manifest's documented
/// behaviour, it is always derived from `ports` and never independently persisted or listed.
nonisolated enum ReferenceBlobKind: String, Sendable, CaseIterable {
    case mapLand = "map-land"
    case mapStatisticalAreas = "map-statistical-areas"
}

/// Background actor over the shared `ModelContainer`'s reference-data entities. Every method is
/// `async` (actor-isolated) so callers never need their own `ModelContext` — see
/// `ReferenceDataStoreProvider.shared` for how call sites outside the sync pipeline (the cached
/// search providers) reach this without threading a container through every view/view-model init.
@ModelActor
actor ReferenceDataStore {

    /// A dataset's locally-synced state, deliberately a plain `Sendable` value (not the `@Model`
    /// entity itself, which isn't `Sendable` and shouldn't leak outside this actor).
    struct StateSnapshot: Equatable, Sendable {
        let collectionId: String
        let version: String
        let schemaVersion: String
        let itemCount: Int?
        let lastModified: String
        let syncedAt: Date
        let payloadFormatVersion: Int
    }

    /// A single item queued for `replace(dataset:items:state:)`, already JSON-encoded by the
    /// caller (`ReferenceDataSyncService`) so this actor stays generic over every dataset's domain
    /// type without needing `Encodable` generics on an actor method.
    struct ItemPayload: Sendable {
        let itemID: String
        let sortName: String
        let payload: Data
    }

    /// This dataset's current locally-synced state, or `nil` if it has never been synced.
    func state(for dataset: ReferenceDataKind) throws -> StateSnapshot? {
        let rawValue = dataset.rawValue
        let descriptor = FetchDescriptor<ReferenceDatasetStateEntity>(
            predicate: #Predicate { $0.dataset == rawValue }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return StateSnapshot(
            collectionId: entity.collectionId,
            version: entity.version,
            schemaVersion: entity.schemaVersion,
            itemCount: entity.itemCount,
            lastModified: entity.lastModified,
            syncedAt: entity.syncedAt,
            payloadFormatVersion: entity.payloadFormatVersion
        )
    }

    /// Whether any item has ever been synced for `dataset` — the basis for the "data not yet
    /// downloaded" empty state (see ADR-0024 "No bundled fallback").
    func hasData(for dataset: ReferenceDataKind) throws -> Bool {
        let rawValue = dataset.rawValue
        var descriptor = FetchDescriptor<ReferenceItemEntity>(predicate: #Predicate { $0.dataset == rawValue })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// Whether *any* dataset has ever synced successfully — used by
    /// `ReferenceDataSyncCoordinator` to decide between the "update failed, kept old data" and
    /// "nothing downloaded yet" failure messages.
    func hasAnyData() throws -> Bool {
        for kind in ReferenceDataKind.allCases where try hasData(for: kind) {
            return true
        }
        for kind in ReferenceBlobKind.allCases where try hasBlob(for: kind) {
            return true
        }
        return false
    }

    /// Every persisted item for `dataset`, alphabetised by `sortName`, as raw JSON payloads — the
    /// cached search providers decode each into their own domain type.
    func items(for dataset: ReferenceDataKind) throws -> [Data] {
        let rawValue = dataset.rawValue
        let descriptor = FetchDescriptor<ReferenceItemEntity>(
            predicate: #Predicate { $0.dataset == rawValue },
            sortBy: [SortDescriptor(\.sortName)]
        )
        return try modelContext.fetch(descriptor).map(\.payload)
    }

    /// Replaces every persisted item for `dataset` and its state in a single save (see ADR-0024
    /// "Atomic replace"): delete the old rows, insert the new ones, update/create the state row,
    /// then one `modelContext.save()`. Nothing is written to disk until that final call, so a
    /// thrown error partway through (there is none today — this method does not itself throw past
    /// the initial fetches) can never leave a half-replaced dataset.
    func replace(dataset: ReferenceDataKind, items: [ItemPayload], state: StateSnapshot) throws {
        let rawValue = dataset.rawValue

        let existingItems = try modelContext.fetch(
            FetchDescriptor<ReferenceItemEntity>(predicate: #Predicate { $0.dataset == rawValue })
        )
        for existing in existingItems {
            modelContext.delete(existing)
        }

        for item in items {
            modelContext.insert(ReferenceItemEntity(
                key: "\(rawValue).\(item.itemID)",
                dataset: rawValue,
                itemID: item.itemID,
                sortName: item.sortName,
                payload: item.payload
            ))
        }

        let existingState = try modelContext.fetch(
            FetchDescriptor<ReferenceDatasetStateEntity>(predicate: #Predicate { $0.dataset == rawValue })
        ).first

        if let existingState {
            existingState.collectionId = state.collectionId
            existingState.version = state.version
            existingState.schemaVersion = state.schemaVersion
            existingState.itemCount = state.itemCount
            existingState.lastModified = state.lastModified
            existingState.syncedAt = state.syncedAt
            existingState.payloadFormatVersion = state.payloadFormatVersion
        } else {
            modelContext.insert(ReferenceDatasetStateEntity(
                dataset: rawValue,
                collectionId: state.collectionId,
                version: state.version,
                schemaVersion: state.schemaVersion,
                itemCount: state.itemCount,
                lastModified: state.lastModified,
                syncedAt: state.syncedAt,
                payloadFormatVersion: state.payloadFormatVersion
            ))
        }

        try modelContext.save()
    }

    // MARK: - Blob datasets (map-land / map-statistical-areas — see ADR-0024 "Map data")

    /// A blob dataset's current locally-synced state, or `nil` if it has never been synced.
    /// Reuses `StateSnapshot`/`ReferenceDatasetStateEntity` — the state row's shape (version/
    /// collectionId/schemaVersion/syncedAt/payloadFormatVersion) is identical for an item or a
    /// blob dataset; only `itemCount` is always `nil` for a blob (the manifest's blob entries
    /// carry `featureCount`/`sizeBytes` instead, which this connector does not track).
    func blobState(for dataset: ReferenceBlobKind) throws -> StateSnapshot? {
        let rawValue = dataset.rawValue
        let descriptor = FetchDescriptor<ReferenceDatasetStateEntity>(
            predicate: #Predicate { $0.dataset == rawValue }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return StateSnapshot(
            collectionId: entity.collectionId,
            version: entity.version,
            schemaVersion: entity.schemaVersion,
            itemCount: entity.itemCount,
            lastModified: entity.lastModified,
            syncedAt: entity.syncedAt,
            payloadFormatVersion: entity.payloadFormatVersion
        )
    }

    /// Whether `dataset` has ever synced successfully.
    func hasBlob(for dataset: ReferenceBlobKind) throws -> Bool {
        let rawValue = dataset.rawValue
        var descriptor = FetchDescriptor<ReferenceBlobEntity>(predicate: #Predicate { $0.dataset == rawValue })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// `dataset`'s persisted raw bytes, or `nil` if it has never been synced.
    func blob(for dataset: ReferenceBlobKind) throws -> Data? {
        let rawValue = dataset.rawValue
        let descriptor = FetchDescriptor<ReferenceBlobEntity>(predicate: #Predicate { $0.dataset == rawValue })
        return try modelContext.fetch(descriptor).first?.payload
    }

    /// Replaces a blob dataset's bytes and its state in a single save — the blob equivalent of
    /// `replace(dataset:items:state:)` above (see ADR-0024 "Atomic replace"/"Map data").
    func replaceBlob(dataset: ReferenceBlobKind, payload: Data, state: StateSnapshot) throws {
        let rawValue = dataset.rawValue

        if let existingBlob = try modelContext.fetch(
            FetchDescriptor<ReferenceBlobEntity>(predicate: #Predicate { $0.dataset == rawValue })
        ).first {
            existingBlob.payload = payload
        } else {
            modelContext.insert(ReferenceBlobEntity(dataset: rawValue, payload: payload))
        }

        let existingState = try modelContext.fetch(
            FetchDescriptor<ReferenceDatasetStateEntity>(predicate: #Predicate { $0.dataset == rawValue })
        ).first

        if let existingState {
            existingState.collectionId = state.collectionId
            existingState.version = state.version
            existingState.schemaVersion = state.schemaVersion
            existingState.itemCount = state.itemCount
            existingState.lastModified = state.lastModified
            existingState.syncedAt = state.syncedAt
            existingState.payloadFormatVersion = state.payloadFormatVersion
        } else {
            modelContext.insert(ReferenceDatasetStateEntity(
                dataset: rawValue,
                collectionId: state.collectionId,
                version: state.version,
                schemaVersion: state.schemaVersion,
                itemCount: state.itemCount,
                lastModified: state.lastModified,
                syncedAt: state.syncedAt,
                payloadFormatVersion: state.payloadFormatVersion
            ))
        }

        try modelContext.save()
    }
}

/// Holds the app-wide `ReferenceDataStore` instance so call sites that default-construct a cached
/// provider (e.g. `CachedPortSearchProvider()` as a view model's default parameter) can reach it
/// without threading a `ModelContainer` through every init — mirrors `LaunchArguments.current`'s
/// "read a process-wide seam without DI plumbing" role. Set once, from `RecordCatchApp.init()`,
/// before any provider is constructed; `nonisolated(unsafe)` is safe here because the write always
/// happens-before any read in practice (app launch, single-threaded `@main` entry).
enum ReferenceDataStoreProvider {
    nonisolated(unsafe) static var shared: ReferenceDataStore?

    static func bootstrap(modelContainer: ModelContainer) {
        shared = ReferenceDataStore(modelContainer: modelContainer)
    }
}
