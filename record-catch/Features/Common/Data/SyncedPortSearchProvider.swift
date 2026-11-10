//
//  SyncedPortSearchProvider.swift
//  record-catch
//
//  Port search backed by the on-device reference-data sync pipeline (see ADR-0024 "Consumers"),
//  replacing the bundled `ports.geojson` fixture in production. Mirrors `BundledPortSearchProvider`
//  exactly (same minimum-characters rule, same pure `filtered(...)` helper) so
//  `AddPortViewModel`/`AddPortView` need no changes beyond which provider is injected.
//

import Foundation

/// Reads every synced `PortOption` from `ReferenceDataStore`, caching the result for the lifetime
/// of this instance (a fresh instance is constructed per screen — see `CatchRecordHostView`).
/// Inactive ports (`isActive == false`) are excluded, mirroring a server that has retired a port
/// but not yet removed its historical record.
nonisolated struct SyncedPortSearchProvider: PortSearchProviding {

    let minimumCharacters: Int
    private let store: ReferenceDataStore?

    init(minimumCharacters: Int = 2, store: ReferenceDataStore? = ReferenceDataStoreProvider.shared) {
        self.minimumCharacters = minimumCharacters
        self.store = store
    }

    func searchPorts(matching query: String) async throws -> [PortOption] {
        let ports = try await loadPorts()
        return BundledPortSearchProvider.filtered(query: query, minimumCharacters: minimumCharacters, ports: ports)
    }

    func allPorts() async throws -> [PortOption] {
        try await loadPorts()
    }

    /// Loads, filters out inactive ports and sorts alphabetically — the store itself already
    /// sorts by `sortName`, but an inactive-port filter can't be expressed in the actor's generic
    /// `decodedItems(for:as:)` read, so filtering happens here instead.
    private func loadPorts() async throws -> [PortOption] {
        guard let store else { return [] }
        let ports = try await store.decodedItems(for: .ports, as: PortOption.self)
        return ports.filter { $0.isActive ?? true }
    }
}
