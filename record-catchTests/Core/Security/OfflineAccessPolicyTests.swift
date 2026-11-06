import XCTest
@testable import record_catch

/// Pure decision logic — ≥95% core-logic coverage target (testing.instructions.md), fully
/// exercised here (ADR-0022 §5: the 7-day offline grace period).
final class OfflineAccessPolicyTests: XCTestCase {

    private let referenceNow = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func test_disallowed_neverAllowsOfflineAccess_evenWithRecentVerification() {
        let allowed = OfflineAccessPolicy.disallowed.allowsOfflineAccess(
            lastVerified: referenceNow,
            now: referenceNow
        )
        XCTAssertFalse(allowed)
    }

    func test_indefinite_allowsOfflineAccess_regardlessOfElapsedTime() {
        let longAgo = referenceNow.addingTimeInterval(-365 * 86_400)
        let allowed = OfflineAccessPolicy.indefinite.allowsOfflineAccess(lastVerified: longAgo, now: referenceNow)
        XCTAssertTrue(allowed)
    }

    func test_indefinite_withNoVerification_returnsFalse() {
        let allowed = OfflineAccessPolicy.indefinite.allowsOfflineAccess(lastVerified: nil, now: referenceNow)
        XCTAssertFalse(allowed)
    }

    func test_gracePeriod_withNoVerification_returnsFalse() {
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: nil, now: referenceNow)
        XCTAssertFalse(allowed)
    }

    func test_gracePeriod_withinWindow_returnsTrue() {
        let lastVerified = referenceNow.addingTimeInterval(-6 * 86_400)
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: lastVerified, now: referenceNow)
        XCTAssertTrue(allowed)
    }

    func test_gracePeriod_atExactBoundary_returnsTrue() {
        let lastVerified = referenceNow.addingTimeInterval(-7 * 86_400)
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: lastVerified, now: referenceNow)
        XCTAssertTrue(allowed)
    }

    func test_gracePeriod_justPastBoundary_returnsFalse() {
        let lastVerified = referenceNow.addingTimeInterval(-7 * 86_400 - 1)
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: lastVerified, now: referenceNow)
        XCTAssertFalse(allowed)
    }

    func test_gracePeriod_longPastWindow_returnsFalse() {
        let lastVerified = referenceNow.addingTimeInterval(-30 * 86_400)
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: lastVerified, now: referenceNow)
        XCTAssertFalse(allowed)
    }

    func test_gracePeriod_withFutureDatedVerification_returnsFalse() {
        // Device clock tampering must never extend offline access (ADR-0022 §5).
        let future = referenceNow.addingTimeInterval(86_400)
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: future, now: referenceNow)
        XCTAssertFalse(allowed)
    }

    func test_gracePeriod_withVerificationExactlyNow_returnsTrue() {
        let allowed = OfflineAccessPolicy.gracePeriod(days: 7).allowsOfflineAccess(lastVerified: referenceNow, now: referenceNow)
        XCTAssertTrue(allowed)
    }

    func test_current_isSevenDayGracePeriod() {
        XCTAssertEqual(OfflineAccessPolicy.current, .gracePeriod(days: 7))
    }
}
