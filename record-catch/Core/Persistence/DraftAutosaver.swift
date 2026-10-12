import Foundation

/// Debounces `CatchRecordDraft` saves so edits are persisted automatically without waiting for
/// the user to reach a route boundary (see BR-SUB-008/AC14 — "the draft record is automatically
/// saved within 10 seconds of the last change").
///
/// `CatchRecordHostView` already persists on every "Save and continue" (route push, ADR-0014
/// decision #5); this autosaver is the belt-and-braces layer that also catches in-progress edits
/// on the *current* screen (e.g. partially-typed fields) that would otherwise be lost if the app
/// is terminated before the user reaches the next screen.
///
/// `sleep` is injectable (defaulting to `Task.sleep(for:)`) so the debounce interval can be
/// exercised deterministically in unit tests — no wall-clock waits, no flaky timing.
@MainActor
final class DraftAutosaver {

    /// Comfortably inside the 10-second AC14 ceiling, while still coalescing rapid successive
    /// edits (e.g. typing) into a single save.
    static let defaultInterval: Duration = .seconds(2)

    private let store: CatchRecordDraftStoring
    private let interval: Duration
    private let sleep: (Duration) async throws -> Void
    private var pendingTask: Task<Void, Never>?

    init(
        store: CatchRecordDraftStoring,
        interval: Duration = DraftAutosaver.defaultInterval,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.interval = interval
        self.sleep = sleep
    }

    /// Schedules `draft` to be saved once `interval` has elapsed with no further call to
    /// `schedule`/`flush` — i.e. a debounce. Cancels any previously scheduled save, so rapid
    /// successive edits coalesce into a single save rather than saving on every keystroke.
    func schedule(_ draft: CatchRecordDraft) {
        pendingTask?.cancel()
        pendingTask = Task { [interval, sleep, store] in
            do {
                try await sleep(interval)
            } catch {
                // Cancelled by a newer edit (`schedule`) or an explicit `flush` — the newer call
                // is responsible for persisting, so there is nothing to do here.
                return
            }
            guard !Task.isCancelled else { return }
            try? await store.save(draft)
        }
    }

    /// Saves `draft` immediately, cancelling any pending debounced save. Used when the app is
    /// about to leave the foreground (see `CatchRecordHostView`'s `scenePhase` observer), so an
    /// edit mid-debounce is not lost if the process is suspended or terminated.
    func flush(_ draft: CatchRecordDraft) {
        pendingTask?.cancel()
        pendingTask = nil
        Task { try? await store.save(draft) }
    }
}
