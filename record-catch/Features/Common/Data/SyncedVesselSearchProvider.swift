//
//  SyncedVesselSearchProvider.swift
//  record-catch
//
//  Vessel source backed by the on-device reference-data sync pipeline (see ADR-0024/ADR-0028),
//  replacing the old static two-vessel list. Mirrors `SyncedPortSearchProvider` exactly (reads
//  every synced item, filters out anything inactive).
//

import Foundation

/// Reads every synced `VesselOption` from `ReferenceDataStore`. A fresh instance is constructed
/// per screen (see `CatchRecordHostView`/`SelectVesselView`), mirroring `SyncedPortSearchProvider`.
nonisolated struct SyncedVesselSearchProvider: VesselProviding {

    private let store: ReferenceDataStore?

    init(store: ReferenceDataStore? = ReferenceDataStoreProvider.shared) {
        self.store = store
    }

    func vessels() async -> [VesselOption] {
        guard let store else { return [] }
        let vessels = (try? await store.decodedItems(for: .vessels, as: VesselOption.self)) ?? []
        return vessels
            .filter(Self.isActive)
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// A vessel counts as active unless the API explicitly says otherwise: `status` is anything
    /// other than (case-insensitively) `"active"`, or `activeTo` is a date in the past — mirrors
    /// `SyncedPortSearchProvider`'s `isActive` filter for ports. A vessel with no `status`/
    /// `activeTo` at all (e.g. a hand-built fixture) is treated as active.
    private static func isActive(_ vessel: VesselOption) -> Bool {
        if let status = vessel.status, status.caseInsensitiveCompare("active") != .orderedSame {
            return false
        }
        if let activeTo = vessel.activeTo, let date = Self.dateFormatter.date(from: activeTo), date < Date() {
            return false
        }
        return true
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        return formatter
    }()
}
