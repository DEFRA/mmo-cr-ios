import Foundation

/// Pure, static routing decisions for the "Create a catch record" journey.
///
/// Kept out of the router/views so the entry-point rule is trivially unit-testable with no
/// `NavigationStack` host required.
enum CatchRecordRouting {

    /// Resolves the route to enter when a submissions-table date link is tapped.
    ///
    /// Only an **Unsent** (draft) row has a defined next step in this phase; every other status
    /// resolves to `nil` and stays inert, matching current Home behaviour.
    static func entryRoute(for row: SubmissionRow) -> CatchRecordRoute? {
        guard row.status == .unsent else { return nil }
        return .draftAction(row)
    }
}
