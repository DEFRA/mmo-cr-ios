//
//  ReferenceDataManifest.swift
//  record-catch
//
//  Decodes `GET /api/v1/reference-data/manifest` (see ADR-0018 addendum "Manifest"). Gives the
//  active version/GUID/itemCount of every persisted dataset — the intended basis for a future
//  change-detection/sync strategy. **Not wired into `AppEnvironment`, any view model, or any
//  persistence in this change** — connector-only, matching the scope of the existing
//  vessels/species/ports methods (see ADR-0018).
//

import Foundation

/// One dataset's entry in the active manifest. `dataset` and `format` are kept as plain `String`
/// (not `ReferenceDataset`) so entries for datasets the app doesn't model yet (`gears`,
/// `map-land`, `map-statistical-areas`) decode harmlessly instead of failing the whole manifest.
nonisolated struct ReferenceDataManifestEntry: Decodable, Equatable, Sendable {
    let dataset: String
    let collectionId: String
    let version: String
    let schemaVersion: String
    let format: String
    let itemCount: Int
    let lastModified: String
    let url: String
}

/// The active manifest: every persisted dataset's current version. Never includes `map-ports`
/// (always derived from `ports`, never independently persisted or listed — see ADR-0018
/// addendum).
nonisolated struct ReferenceDataManifest: Decodable, Equatable, Sendable {
    let manifestId: String
    let version: String
    let datasets: [ReferenceDataManifestEntry]
}
