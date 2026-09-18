import SwiftUI

/// Posts VoiceOver announcements without moving focus (WCAG 2.2 SC 4.1.3 Status Messages).
///
/// Extracted from `SearchDropdownField` (its original, single call site) so every screen that
/// needs to announce a validation-error or results-count change to assistive technology shares one
/// implementation. Uses the iOS 17+ `AccessibilityNotification.Announcement` API where available,
/// falling back to the `UIAccessibility` notification on iOS 16 (the app's minimum deployment
/// target).
enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        if #available(iOS 17, *) {
            var announcement = AttributedString(message)
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
