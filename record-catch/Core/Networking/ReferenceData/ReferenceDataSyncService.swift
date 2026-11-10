//
//  ReferenceDataSyncService.swift
//  record-catch
//
//  Orchestrates one manifest-driven reference-data sync (see ADR-0024): fetch the manifest,
//  decide which of `ports`/`species`/`gears`/`vessels` changed, fetch+validate+persist each
//  independently and concurrently. Connectivity/throttling/triggers are the *coordinator*'s job
//  (`ReferenceDataSyncCoordinator`) — this actor assumes it is only ever called when a sync should
//  actually be attempted, and reports exactly what happened per dataset via `SyncReport`.
//

import Foundation

/// The outcome for a single dataset within one `ReferenceDataSyncService.sync()` run.
nonisolated enum DatasetSyncResult: Sendable, Equatable {
    /// Fetched, validated and persisted successfully.
    case updated
    /// The manifest showed no change (and local data already exists) — skipped the fetch.
    case unchanged
    /// A fetch, validation or persistence step failed; the existing on-device snapshot (if any)
    /// was kept untouched. `reason` is a short, non-sensitive diagnostic label (never raw response
    /// content or personal data) suitable for `NetworkLogger`.
    case failed(reason: String)
}

/// The result of one sync run, keyed by `ReferenceDataKind.rawValue`.
nonisolated struct ReferenceDataSyncReport: Sendable, Equatable {
    var results: [String: DatasetSyncResult] = [:]

    /// Whether every dataset either updated or was already unchanged — no failures at all.
    var isFullSuccess: Bool {
        results.values.allSatisfy {
            if case .failed = $0 { return false }
            return true
        }
    }

    /// Whether at least one dataset failed.
    var hasFailure: Bool {
        results.values.contains { if case .failed = $0 { return true } else { return false } }
    }
}

/// Runs one sync pass against the reference-data API, persisting through `ReferenceDataStore`.
/// An `actor` (not `@MainActor`) since every step here is I/O/CPU work that must never block the
/// UI thread — `ReferenceDataSyncCoordinator` is the `@MainActor` façade callers actually use.
actor ReferenceDataSyncService {

    /// This app's current payload-format version for every dataset this service persists (see
    /// `ReferenceDatasetStateEntity.payloadFormatVersion`). Bump this whenever a domain type's
    /// `Codable` shape changes in a way that isn't safely forward/backward compatible — this
    /// connector does not support schema migrations (ADR-0024 "No migrations"), so a bump simply
    /// forces every device to refetch once, which is cheap and correct for these small datasets.
    static let payloadFormatVersion = 1

    private let client: ReferenceDataFetching
    private let store: ReferenceDataStore
    private let logger: NetworkLogger

    init(client: ReferenceDataFetching, store: ReferenceDataStore, logger: NetworkLogger = NetworkLogger()) {
        self.client = client
        self.store = store
        self.logger = logger
    }

    /// Whether at least one dataset has ever synced successfully — used by the coordinator to
    /// distinguish "update failed, kept old data" from "nothing downloaded yet".
    func hasAnyData() async -> Bool {
        (try? await store.hasAnyData()) ?? false
    }

    /// Fetches the manifest, then fetches+validates+persists every changed dataset concurrently.
    /// Never throws: a manifest failure means every dataset reports `.failed` (there is nothing
    /// to compare against, so none can be skipped as "unchanged"); a per-dataset failure never
    /// stops the others.
    func sync() async -> ReferenceDataSyncReport {
        let manifest: ReferenceDataManifest?
        do {
            manifest = try await client.fetchManifest()
        } catch {
            let reason = Self.describe(error)
            logger.log(NetworkLogEntry(
                method: "GET",
                path: "manifest",
                statusCode: nil,
                durationSeconds: 0,
                errorCode: "sync_manifest_failed:\(reason)"
            ))
            manifest = nil
        }

        var report = ReferenceDataSyncReport()
        await withTaskGroup(of: (ReferenceDataKind, DatasetSyncResult).self) { group in
            for kind in ReferenceDataKind.allCases {
                let manifestEntry = manifest?.datasets.first { $0.dataset == kind.rawValue }
                group.addTask { [self] in
                    (kind, await self.syncDataset(kind, manifestEntry: manifestEntry, manifestFetched: manifest != nil))
                }
            }
            for await (kind, result) in group {
                report.results[kind.rawValue] = result
            }
        }
        return report
    }

    /// Decides whether `kind` needs refetching, and if so fetches, validates and persists it.
    private func syncDataset(
        _ kind: ReferenceDataKind,
        manifestEntry: ReferenceDataManifestEntry?,
        manifestFetched: Bool
    ) async -> DatasetSyncResult {
        let existingState = try? await store.state(for: kind)

        if manifestFetched, let manifestEntry, let existingState, unchanged(existingState, matches: manifestEntry) {
            return .unchanged
        }
        guard manifestFetched else {
            // No manifest to compare against this run; only worth attempting a blind refetch if
            // nothing is persisted yet at all (first sync after sign-in with a flaky manifest
            // call) — otherwise keep the existing snapshot rather than guessing.
            guard existingState == nil else { return .unchanged }
            return await fetchValidateAndStore(kind, manifestEntry: nil)
        }
        return await fetchValidateAndStore(kind, manifestEntry: manifestEntry)
    }

    /// Whether a locally-synced state already matches a manifest entry closely enough to skip
    /// refetching: same version/collectionId/schemaVersion, the same manifest `itemCount` (when
    /// present), and the data was synced with the app's *current* payload-format version.
    private func unchanged(
        _ state: ReferenceDataStore.StateSnapshot,
        matches entry: ReferenceDataManifestEntry
    ) -> Bool {
        state.collectionId == entry.collectionId
            && state.version == entry.version
            && state.schemaVersion == entry.schemaVersion
            && state.itemCount == entry.itemCount
            && state.payloadFormatVersion == Self.payloadFormatVersion
    }

    private func fetchValidateAndStore(
        _ kind: ReferenceDataKind,
        manifestEntry: ReferenceDataManifestEntry?
    ) async -> DatasetSyncResult {
        do {
            let items = try await fetchAndValidate(kind, manifestEntry: manifestEntry)
            let state = ReferenceDataStore.StateSnapshot(
                collectionId: manifestEntry?.collectionId ?? "",
                version: manifestEntry?.version ?? "",
                schemaVersion: manifestEntry?.schemaVersion ?? "",
                itemCount: manifestEntry?.itemCount,
                lastModified: manifestEntry?.lastModified ?? "",
                syncedAt: Date(),
                payloadFormatVersion: Self.payloadFormatVersion
            )
            try await store.replace(dataset: kind, items: items, state: state)
            return .updated
        } catch {
            let reason = Self.describe(error)
            logger.log(NetworkLogEntry(
                method: "GET",
                path: kind.rawValue,
                statusCode: nil,
                durationSeconds: 0,
                errorCode: "sync_dataset_failed:\(reason)"
            ))
            return .failed(reason: reason)
        }
    }

    /// Fetches `kind` via `client`, runs its dataset-specific `ReferenceDataValidator` checks, and
    /// encodes each item into a `ReferenceDataStore.ItemPayload` ready to persist.
    private func fetchAndValidate(
        _ kind: ReferenceDataKind,
        manifestEntry: ReferenceDataManifestEntry?
    ) async throws -> [ReferenceDataStore.ItemPayload] {
        let encoder = JSONEncoder()
        switch kind {
        case .ports:
            let ports = try await client.fetchPorts()
            try ReferenceDataValidator.validateItemCount(
                dataset: kind.rawValue, itemCount: ports.count, manifestEntry: manifestEntry
            )
            try ReferenceDataValidator.validatePorts(ports)
            return try ports.map { try makePayload(itemID: $0.id, sortName: $0.name, value: $0, encoder: encoder) }
        case .species:
            let species = try await client.fetchSpecies()
            try ReferenceDataValidator.validateItemCount(
                dataset: kind.rawValue, itemCount: species.count, manifestEntry: manifestEntry
            )
            try ReferenceDataValidator.validateSpecies(species)
            return try species.map { try makePayload(itemID: $0.id, sortName: $0.name, value: $0, encoder: encoder) }
        case .vessels:
            let vessels = try await client.fetchVessels()
            try ReferenceDataValidator.validateItemCount(
                dataset: kind.rawValue, itemCount: vessels.count, manifestEntry: manifestEntry
            )
            try ReferenceDataValidator.validateVessels(vessels)
            return try vessels.map { try makePayload(itemID: $0.id, sortName: $0.name, value: $0, encoder: encoder) }
        case .gears:
            let gears = try await client.fetchGears()
            try ReferenceDataValidator.validateItemCount(
                dataset: kind.rawValue, itemCount: gears.count, manifestEntry: manifestEntry
            )
            try ReferenceDataValidator.validateGears(gears)
            return try gears.map { try makePayload(itemID: $0.id, sortName: $0.name, value: $0, encoder: encoder) }
        }
    }

    private func makePayload<Value: Encodable>(
        itemID: String,
        sortName: String,
        value: Value,
        encoder: JSONEncoder
    ) throws -> ReferenceDataStore.ItemPayload {
        ReferenceDataStore.ItemPayload(itemID: itemID, sortName: sortName, payload: try encoder.encode(value))
    }

    /// Short, non-sensitive diagnostic label for an error — never raw response content.
    private static func describe(_ error: Error) -> String {
        switch error {
        case let apiError as APIError:
            return "APIError.\(apiError)"
        case let validationError as ReferenceDataValidationError:
            return "ReferenceDataValidationError.\(validationError)"
        default:
            return String(describing: type(of: error))
        }
    }
}
