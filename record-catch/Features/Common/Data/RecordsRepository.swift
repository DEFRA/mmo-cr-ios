import Foundation

/// Supplies submitted/amended/late records from the (not-yet-built) MMO backend.
///
/// API-shaped stub seam, mirroring `FavouritePortsProviding`/`CatchRecordSubmissionServicing` (see
/// ADR-0004/0015): there is no real backend yet, so `StubServerRecordsProvider` returns a fixed set
/// of fixtures. A real implementation can swap in later without changing `MergingRecordsRepository`
/// or its tests.
nonisolated protocol ServerRecordsProviding: Sendable {
    /// Every server-held record (submitted, amended, late) visible to the current user.
    func serverRecords() async throws -> [SubmissionRow]
}

/// Fixed, always-succeeding fixtures standing in for the real Records API (see ADR-0015). Kept
/// deliberately small and static — this app has no real backend or auth yet.
nonisolated struct StubServerRecordsProvider: ServerRecordsProviding {

    private static let fixtureDateText = "20 Nov 2020"
    private static let fixtureDate: Date = {
        var components = DateComponents(year: 2020, month: 11, day: 20)
        components.calendar = Calendar(identifier: .gregorian)
        return components.date ?? .distantPast
    }()

    func serverRecords() async throws -> [SubmissionRow] {
        [
            SubmissionRow(dateText: Self.fixtureDateText, vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith", sortDate: Self.fixtureDate),
            SubmissionRow(dateText: Self.fixtureDateText, vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith", sortDate: Self.fixtureDate),
            SubmissionRow(dateText: Self.fixtureDateText, vesselName: "ACHILLES", status: .late, createdBy: "J.Smith", sortDate: Self.fixtureDate)
        ]
    }
}

/// Supplies the merged, ordered list of rows for Home's trips table: local Unsent drafts (from
/// `CatchRecordDraftStoring`) plus server records (from `ServerRecordsProviding`) — see ADR-0015.
///
/// Explicitly `nonisolated` (mirroring `FavouritePortsProviding`, etc.) so any conformer, in this
/// module or a test target, satisfies the same, unambiguous isolation for `records()` regardless
/// of where it is declared; every production conformer (`MergingRecordsRepository`) still runs on
/// the main actor via its own `@MainActor` class annotation, and every call site already runs on
/// the main actor.
nonisolated protocol RecordsProviding {
    func records() async throws -> [SubmissionRow]
}

/// Errors that can occur loading the merged Home records list.
nonisolated enum RecordsLoadError: Error, Equatable {
    /// The server records could not be reached (offline, timeout, server error, ...). Local Unsent
    /// drafts are always available regardless (offline-first — see ADR-0015), so this is only
    /// raised when even the local draft store itself fails, which should not normally happen.
    case unavailable
}

/// Pure helpers for building and ordering Home rows from persisted local drafts — kept as a
/// free-standing, non-actor-isolated namespace (mirroring `CatchRecordRouting`) so they are
/// trivially unit-testable from any context, with no dependency on `MergingRecordsRepository`'s
/// own `@MainActor` isolation.
enum RecordsMerging {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    /// Placeholder text shown for a draft field not yet captured (e.g. vessel/trip end date before
    /// those journey screens are reached) — see ADR-0015.
    static let placeholder = "—"
    /// Placeholder "Created by" for local drafts — there is no real auth/user identity yet.
    static let localCreatedByPlaceholder = "You"

    /// Builds the Home row for a persisted local draft, using placeholder text for any field not
    /// yet captured.
    static func row(for summary: UnsentDraftSummary) -> SubmissionRow {
        SubmissionRow(
            dateText: summary.tripEndDate.map { dateFormatter.string(from: $0) } ?? placeholder,
            vesselName: summary.vessel ?? placeholder,
            status: .unsent,
            createdBy: localCreatedByPlaceholder,
            localID: summary.localID,
            sortDate: summary.tripEndDate ?? summary.lastEditedAt
        )
    }

    /// Pure merge/ordering: every row, newest first by `sortDate` (see ADR-0015).
    static func merge(draftRows: [SubmissionRow], serverRows: [SubmissionRow]) -> [SubmissionRow] {
        (draftRows + serverRows).sorted { $0.sortDate > $1.sortDate }
    }
}

/// Configurable `RecordsProviding` test double. Lives here (alongside `StubServerRecordsProvider`,
/// mirroring `StubFavouritePortsProvider` et al. — see ADR-0004) rather than in the test target:
/// an async protocol witness declared in a *different module* than the protocol has been observed
/// to trip a Swift concurrency inference mismatch on this toolchain, so every test double for an
/// app-module async protocol is kept in-module by convention.
nonisolated struct StubRecordsProvider: RecordsProviding {
    let rows: [SubmissionRow]
    let shouldThrow: Bool

    init(rows: [SubmissionRow] = [], shouldThrow: Bool = false) {
        self.rows = rows
        self.shouldThrow = shouldThrow
    }

    func records() async throws -> [SubmissionRow] {
        if shouldThrow { throw RecordsLoadError.unavailable }
        return rows
    }
}

/// The production `RecordsProviding`: local Unsent drafts (always available, offline-first) merged
/// with stubbed server records, newest first. `@unchecked Sendable` because it is confined to the
/// main actor (`@MainActor`) even though one of its stored properties (`CatchRecordDraftStoring`,
/// itself `@MainActor`-isolated) is not itself `Sendable` — safe because every access is already
/// serialised through the main actor.
@MainActor
final class MergingRecordsRepository: RecordsProviding {

    private let draftStore: CatchRecordDraftStoring
    private let serverRecords: ServerRecordsProviding

    init(
        draftStore: CatchRecordDraftStoring,
        serverRecords: ServerRecordsProviding = StubServerRecordsProvider()
    ) {
        self.draftStore = draftStore
        self.serverRecords = serverRecords
    }

    func records() async throws -> [SubmissionRow] {
        let summaries = (try? await draftStore.allUnsentDrafts()) ?? []
        let draftRows = summaries.map { RecordsMerging.row(for: $0) }
        let serverRows = (try? await serverRecords.serverRecords()) ?? []
        return RecordsMerging.merge(draftRows: draftRows, serverRows: serverRows)
    }
}
