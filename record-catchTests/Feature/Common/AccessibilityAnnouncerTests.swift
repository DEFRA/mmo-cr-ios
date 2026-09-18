import XCTest
@testable import record_catch

/// `AccessibilityAnnouncer.announce` posts a VoiceOver notification (or, on iOS 17+, an
/// `AccessibilityNotification.Announcement`) and returns without throwing regardless of whether
/// VoiceOver is actually running — exercising it here confirms the call is safe to make
/// unconditionally from any validation/results-count change, as every call site does.
final class AccessibilityAnnouncerTests: XCTestCase {

    func test_announce_doesNotThrow_forNonEmptyMessage() {
        AccessibilityAnnouncer.announce("5 results")
    }

    func test_announce_doesNotThrow_forEmptyMessage() {
        AccessibilityAnnouncer.announce("")
    }
}
