//
//  ReferenceDataEnvelope.swift
//  record-catch
//
//  Generic response envelope shared by every reference-data dataset (see ADR-0018 §2). Modelled
//  generically over `Item` so adding a future dataset (ports, gear, species) only requires a new
//  DTO, not a new envelope shape.
//

import Foundation

/// The reference-data API's response envelope (the connector requests the default **canonical**
/// view — see ADR-0018's correction note and `ReferenceDataEndpoint`):
/// ```json
/// {
///   "dataset": "vessels",
///   "collectionId": "00000000-0000-4000-8000-000000000010",
///   "schemaVersion": "1.0",
///   "version": "local-seed-1",
///   "view": "canonical",
///   "total": 2,
///   "items": [ … ]
/// }
/// ```
nonisolated struct ReferenceDataEnvelope<Item: Decodable & Sendable>: Decodable, Sendable {
    let dataset: String
    let collectionId: String
    let schemaVersion: String
    let version: String
    let view: String
    let total: Int
    let items: [Item]
}
