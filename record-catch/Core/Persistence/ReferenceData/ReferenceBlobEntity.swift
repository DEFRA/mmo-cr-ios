//
//  ReferenceBlobEntity.swift
//  record-catch
//
//  One persisted raw-blob reference dataset (`map-land`/`map-statistical-areas` — see ADR-0024
//  "Map data"). Unlike `ReferenceItemEntity` (one row per item, shared across `ports`/`species`/
//  `gears`/`vessels`), a blob dataset has no item-level identity to the app — it is stored
//  opaquely, exactly as the API returned it, with one row per dataset.
//

import Foundation
import SwiftData

/// A single blob dataset's raw bytes, keyed by `dataset` (e.g. `"map-land"`). `payload` is marked
/// `.externalStorage` since these GeoJSON blobs can run to several megabytes — SwiftData stores
/// large attributes like this outside the main database file rather than inline. Not personal
/// data — kept across sign-out (see ADR-0024 "Sign-out"), like every other reference dataset.
@Model
final class ReferenceBlobEntity {
    @Attribute(.unique) var dataset: String
    @Attribute(.externalStorage) var payload: Data

    init(dataset: String, payload: Data) {
        self.dataset = dataset
        self.payload = payload
    }
}
