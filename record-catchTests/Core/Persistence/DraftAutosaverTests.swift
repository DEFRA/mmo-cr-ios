import XCTest
@testable import record_catch

/// Exercises `DraftAutosaver`'s debounce/flush behaviour deterministically. `sleep` is injected
/// throughout so these tests never wait on the wall clock (see BR-SUB-008/AC14 — no flaky timing).
@MainActor
final class DraftAutosaverTests: XCTestCase {

    /// Records every `save(_:)` call so assertions can check both count and content.
    private final class RecordingDraftStore: CatchRecordDraftStoring {
        private(set) var savedVessels: [String?] = []

        func save(_ draft: CatchRecordDraft) async throws {
            savedVessels.append(draft.vessel)
        }
        func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload? { nil }
        func deleteDraft(localID: UUID) async throws {}
        func allUnsentDrafts() async throws -> [UnsentDraftSummary] { [] }
    }

    /// A controllable "sleep" that only resumes once the test explicitly signals it, so the
    /// debounce window can be driven step-by-step without any real delay.
    private final class ControllableSleep: @unchecked Sendable {
        private var continuations: [CheckedContinuation<Void, Error>] = []
        private let lock = NSLock()

        func sleep(_ duration: Duration) async throws {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { continuations.append(continuation) }
            }
        }

        /// Resumes every currently-waiting `sleep` call successfully, simulating the debounce
        /// interval elapsing with no further edits.
        func resumeAll() {
            let pending = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
                let current = continuations
                continuations = []
                return current
            }
            pending.forEach { $0.resume() }
        }

        /// Cancels every currently-waiting `sleep` call, simulating `Task.sleep` throwing
        /// `CancellationError` when the owning `Task` is cancelled.
        func cancelAll() {
            let pending = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
                let current = continuations
                continuations = []
                return current
            }
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    // MARK: - schedule: saves once the interval elapses

    func test_schedule_onceSleepResumes_savesTheDraft() async throws {
        let store = RecordingDraftStore()
        let controllable = ControllableSleep()
        let sut = DraftAutosaver(store: store, sleep: controllable.sleep)
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        sut.schedule(draft)
        try await Task.sleep(nanoseconds: 1_000_000) // let `schedule`'s Task reach the sleep call
        controllable.resumeAll()
        try await Task.sleep(nanoseconds: 1_000_000) // let the save complete

        XCTAssertEqual(store.savedVessels, ["ACHILLES"])
    }

    // MARK: - schedule: debounces rapid successive edits into a single save

    func test_schedule_calledRepeatedly_coalescesIntoASingleSave() async throws {
        let store = RecordingDraftStore()
        let controllable = ControllableSleep()
        let sut = DraftAutosaver(store: store, sleep: controllable.sleep)
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        sut.schedule(draft)
        try await Task.sleep(nanoseconds: 1_000_000)
        sut.schedule(draft) // cancels the first pending save before it fires
        try await Task.sleep(nanoseconds: 1_000_000)
        draft.vessel = "HERCULES"
        sut.schedule(draft) // cancels the second, schedules a third with the latest value
        try await Task.sleep(nanoseconds: 1_000_000)

        controllable.resumeAll() // resumes only the one still-pending sleep (the third)
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(store.savedVessels, ["HERCULES"])
    }

    // MARK: - flush: saves immediately without waiting for the interval

    func test_flush_savesImmediately_withoutWaitingForSleep() async throws {
        let store = RecordingDraftStore()
        let controllable = ControllableSleep()
        let sut = DraftAutosaver(store: store, sleep: controllable.sleep)
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        sut.flush(draft)
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(store.savedVessels, ["ACHILLES"])
    }

    func test_flush_cancelsAPendingScheduledSave_soItDoesNotAlsoFire() async throws {
        let store = RecordingDraftStore()
        let controllable = ControllableSleep()
        let sut = DraftAutosaver(store: store, sleep: controllable.sleep)
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        sut.schedule(draft)
        try await Task.sleep(nanoseconds: 1_000_000)
        sut.flush(draft)
        try await Task.sleep(nanoseconds: 1_000_000)
        controllable.resumeAll() // the cancelled pending sleep, if any, must not also save

        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(store.savedVessels, ["ACHILLES"])
    }

    // MARK: - schedule: a cancelled sleep (superseded by a newer edit) does not save

    func test_schedule_whenSleepIsCancelled_doesNotSave() async throws {
        let store = RecordingDraftStore()
        let controllable = ControllableSleep()
        let sut = DraftAutosaver(store: store, sleep: controllable.sleep)
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        sut.schedule(draft)
        try await Task.sleep(nanoseconds: 1_000_000)
        controllable.cancelAll()
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertTrue(store.savedVessels.isEmpty)
    }
}
