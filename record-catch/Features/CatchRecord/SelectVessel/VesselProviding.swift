import Foundation

/// Supplies the vessels a user can pick from on the Select vessel screen, sourced from the
/// reference-data API's `vessels` dataset — downloaded at sign-in alongside ports/species/gears
/// (see ADR-0024/ADR-0028), never a static/bundled list.
///
/// `async` because the production conformer (`SyncedVesselSearchProvider`) reads from the
/// on-device reference-data store, which is actor-isolated.
protocol VesselProviding {
    /// Every vessel available for selection. Inactive vessels are excluded (see
    /// `SyncedVesselSearchProvider`). Empty when nothing has been downloaded yet, or the signed-in
    /// user has no vessels.
    func vessels() async -> [VesselOption]

    /// The vessel matching `name`, used to resolve an already-persisted draft that only recorded
    /// a vessel **name** (every draft from before `CatchRecordDraft.vesselSnapshot` existed — see
    /// `DraftActionViewModel.resumeDraft()`). `nil` when no vessel with that name is known.
    func vessel(named name: String) async -> VesselOption?
}

extension VesselProviding {
    func vessel(named name: String) async -> VesselOption? {
        await vessels().first { $0.name == name }
    }
}

/// Deterministic, fixed vessel list — used by UI tests and previews so neither depends on the
/// on-device reference-data sync pipeline having actually run (see `SyncedVesselSearchProvider`
/// for the real, API-backed implementation used in production). Mirrors the dev Catch Recording
/// Service's own seed data (ACHILLES/SEA SPRAY), including their ids and registration numbers, so
/// UI tests exercise exactly the shape real data has.
nonisolated struct StubVesselProvider: VesselProviding {
    /// Mirrors the dev reference-data API's seeded `vessels` dataset (see
    /// `docs/api/reference-data-api.md`) — kept here rather than only in fixtures so `-uiTest*`
    /// launches never depend on live network access.
    static let defaultVessels: [VesselOption] = [
        VesselOption(
            id: "00000000-0000-4000-8000-000000000011",
            name: "ACHILLES",
            displayName: "ACHILLES PH1234",
            externalMark: "PH1234",
            registrationNumber: "PH1234",
            syncMetadata: VesselOption.SyncMetadata(lengthOverallMetres: 8.74, status: "active")
        ),
        VesselOption(
            id: "00000000-0000-4000-8000-000000000012",
            name: "SEA SPRAY",
            displayName: "SEA SPRAY BM45",
            externalMark: "BM45",
            registrationNumber: "BM45",
            syncMetadata: VesselOption.SyncMetadata(lengthOverallMetres: 11.2, status: "active")
        )
    ]

    private let fixedVessels: [VesselOption]

    init(vessels: [VesselOption] = StubVesselProvider.defaultVessels) {
        self.fixedVessels = vessels
    }

    func vessels() async -> [VesselOption] { fixedVessels }
}
