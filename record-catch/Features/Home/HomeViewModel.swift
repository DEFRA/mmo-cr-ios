import Foundation

/// View model for Home's "Your trips" list.
///
/// Loads the merged local-drafts + server-records list from `RecordsProviding` (see ADR-0015),
/// exposing an explicit load state so the view can render every state accessibly — never an
/// indefinite spinner (see the accessibility instructions).
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

    private let recordsProvider: RecordsProviding

    init(recordsProvider: RecordsProviding) {
        self.recordsProvider = recordsProvider
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
        } catch {
            loadState = .failed
        }
    }
}
