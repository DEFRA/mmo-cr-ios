//
//  ReferenceItemEntity.swift
//  record-catch
//
//  One persisted reference-data item (a port, species, gear or vessel) — see ADR-0024 "SwiftData
//  models". A single shared table backs all four datasets, mirroring `FavouriteEntity`'s "one
//  entity, several payload shapes" design (see ADR-0023/ADR-0024): they only differ in which
//  `Codable` domain type `payload` decodes to, so a future fifth dataset needs no new `@Model`
//  type, only a new `dataset` value and mapping.
//

import Foundation
import SwiftData

/// A single item within a synced reference dataset. `key` (`"<dataset>.<itemID>"`) is the natural
/// unique identity, mirroring `FavouriteEntity.key`. Not personal data — kept across sign-out (see
/// ADR-0024 "Sign-out").
@Model
final class ReferenceItemEntity {
    @Attribute(.unique) var key: String
    var dataset: String
    var itemID: String
    /// Case-insensitive sort key (the item's display name), kept denormalised so a cached provider
    /// can present an alphabetised list without decoding every `payload` up front.
    var sortName: String
    /// JSON-encoded domain value (`PortOption`, `SpeciesOption`, `GearOption` or `VesselOption`).
    var payload: Data

    init(key: String, dataset: String, itemID: String, sortName: String, payload: Data) {
        self.key = key
        self.dataset = dataset
        self.itemID = itemID
        self.sortName = sortName
        self.payload = payload
    }
}
