import Foundation

/// View model for Home's "Your trips" list.
///
/// Loads the merged local-drafts + server-records list from `RecordsProviding` (see ADR-0015),
/// exposing an explicit load state so the view can render every state accessibly — never an
/// indefinite spinner (see the accessibility instructions). Also owns the GDS-style pagination
/// over that list (client-side only — the full merged list is already loaded in memory, so there
/// is no server-side paging API to call): `currentPage`/`pageSize` back the pure `PaginationState`
/// shown by `PaginationControls`, and `pagedRows` is the slice `HomeView` actually renders, so the
/// "Showing X to Y of Z" text and the visible rows can never drift apart (previously `HomeView`
/// rendered every row regardless of page while the control still claimed a page size of 4).
@MainActor
@Observable
final class HomeViewModel {

    /// The current state of the Home records list.
    enum LoadState: Equatable {
        case loading
        case loaded
        /// Loaded successfully, but there are no records to show yet.
        case empty
        /// The (stubbed) records source failed; local Unsent drafts are still shown if any were
        /// already loaded successfully in a previous attempt (offline-first — see ADR-0015).
        case failed
    }

    private(set) var rows: [SubmissionRow] = []
    private(set) var loadState: LoadState = .loading

    /// The number of rows shown per pagination page. Fixed per instance — not expected to change
    /// at runtime — so it stays a `let`, injectable for previews/tests that want a smaller/larger
    /// page.
    let pageSize: Int

    /// The 1-based page currently shown. `private(set)` — only this view model's own paging
    /// intents (`goToPage(_:)`, `goToPrevious()`, `goToNext()`) and `load()`'s re-clamp may change
    /// it, so `HomeView` can never drive it out of step with `rows`.
    private(set) var currentPage: Int

    private let recordsProvider: RecordsProviding

    init(recordsProvider: RecordsProviding, initialPage: Int = 1, pageSize: Int = 4) {
        self.recordsProvider = recordsProvider
        self.currentPage = max(1, initialPage)
        self.pageSize = max(1, pageSize)
    }

    /// Loads (or reloads) the merged records list. Safe to call repeatedly (e.g. on first
    /// appearance and again whenever the user returns from the "Create a catch record" journey —
    /// see `HomeView`), so a newly-saved or deleted draft is reflected without restarting the app.
    func load() async {
        loadState = .loading
        do {
            let loaded = try await recordsProvider.records()
            rows = loaded
            loadState = loaded.isEmpty ? .empty : .loaded
            // Re-clamp in case the list shrank (e.g. a draft was deleted) while the user was on a
            // page that no longer exists — without this, `pagedRows` could resolve to an empty
            // slice even though earlier pages still have rows to show.
            currentPage = paginationState.currentPage
        } catch {
            loadState = .failed
        }
    }

    /// Pure pagination presentation state, derived from the live `rows.count` so it always
    /// reflects the current list (see `PaginationState`'s own doc comment on this pattern).
    var paginationState: PaginationState {
        PaginationState(currentPage: currentPage, itemCount: rows.count, pageSize: pageSize)
    }

    /// The slice of `rows` for `currentPage` — what `HomeView` should actually render in the
    /// table. Derived from `paginationState`'s already-clamped bounds, so this can never index
    /// out of range even if `currentPage` is momentarily stale.
    var pagedRows: [SubmissionRow] {
        guard !rows.isEmpty else { return [] }
        let state = paginationState
        let startIndex = state.firstItemOnPage - 1
        let endIndex = state.lastItemOnPage
        guard startIndex >= 0, startIndex < endIndex, endIndex <= rows.count else { return [] }
        return Array(rows[startIndex..<endIndex])
    }

    /// Jumps to `page`, clamped to the valid range by `PaginationState`'s own initializer.
    func goToPage(_ page: Int) {
        currentPage = PaginationState(currentPage: page, itemCount: rows.count, pageSize: pageSize).currentPage
    }

    /// Moves to the previous page, if one exists; otherwise does nothing.
    func goToPrevious() {
        guard paginationState.canGoPrevious else { return }
        currentPage -= 1
    }

    /// Moves to the next page, if one exists; otherwise does nothing.
    func goToNext() {
        guard paginationState.canGoNext else { return }
        currentPage += 1
    }
}
