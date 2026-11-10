//
//  ReferenceDataValidationError.swift
//  record-catch
//
//  Typed errors for data this connector refuses to persist (see ADR-0024 "Validation"). Distinct
//  from `APIError`: these never come from the transport layer or an HTTP status — they are raised
//  *after* a successful, well-formed 2xx response, when the payload itself fails a sanity check
//  (e.g. an empty dataset, a manifest/response version mismatch, or — for `gears` — the two
//  requests ADR-0024 fetches disagreeing with each other). Any of these failing a dataset update
//  means the sync keeps the existing on-device snapshot and reports the dataset as failed (see
//  `ReferenceDataSyncService`) — never a partial or corrupt replace.
//

import Foundation

/// Raised by `ReferenceDataValidator` (and the `gears` canonical/mobile join in
/// `RemoteReferenceDataClient.fetchGears()`) when a reference-data response cannot be trusted
/// enough to replace the on-device snapshot. The associated `String`s are non-sensitive,
/// diagnostic-only descriptions (dataset names, counts, codes) — never raw response bodies or
/// personal data — suitable for `NetworkLogger`.
nonisolated enum ReferenceDataValidationError: Error, Sendable, Equatable {
    /// The response's `items` array was empty.
    case emptyDataset(dataset: String)
    /// The response's `total` field didn't match `items.count`.
    case totalMismatch(dataset: String, total: Int, itemCount: Int)
    /// The response's `dataset` field didn't match the dataset requested.
    case datasetMismatch(expected: String, actual: String)
    /// The response's `version`/`collectionId` didn't match the manifest entry that triggered
    /// this fetch (a stale or inconsistent read between the manifest check and the fetch).
    case manifestMismatch(dataset: String)
    /// The manifest's `itemCount` (when present) didn't match the response's actual item count.
    case itemCountMismatch(dataset: String, expected: Int, actual: Int)
    /// Two or more items shared the same identifier.
    case duplicateIdentifier(dataset: String, identifier: String)
    /// A single item failed a dataset-specific sanity check (e.g. a blank name, an out-of-range
    /// coordinate). `reason` is a short, non-sensitive diagnostic label.
    case invalidItem(dataset: String, identifier: String, reason: String)
    /// The response body exceeded the connector's size cap — see `ReferenceDataValidator.maximumResponseSizeBytes`.
    case responseTooLarge(dataset: String, sizeBytes: Int)
    /// `gears`' two requests (canonical + `?view=mobile` — see ADR-0024 "Gears from two
    /// requests") disagreed on `version`/`collectionId`/the set of gear codes present.
    case gearViewsMismatch(reason: String)
    /// A gear's `requiredMeasurementIds`/`variableMeasurementIds` referenced a measurement id
    /// absent from the mobile response's `measurements` catalogue.
    case unresolvedGearMeasurement(gearCode: String, measurementId: String)
}
