import SwiftUI

enum AppTypography {
    // SF-based approximation of GOV.UK typography scale.
    static let pageCaption = Font.system(size: 24, weight: .regular)
    static let pageTitle = Font.system(size: 34, weight: .bold)
    static let body = Font.system(size: 19, weight: .regular)
    static let bodySmall = Font.system(size: 16, weight: .regular)
    static let warningBox = Font.system(size: 18, weight: .bold)
    static let button = Font.system(size: 19, weight: .semibold)
    static let fieldLabel = Font.system(size: 16, weight: .regular)
    static let hint = Font.system(size: 16, weight: .regular)
    static let error = Font.system(size: 16, weight: .semibold)
    static let headerTitle = Font.system(size: 20, weight: .bold)
    static let footerHeading = Font.system(size: 17, weight: .semibold)
    /// Bold, 24pt with a 30pt line height (6pt extra line spacing — see `.lineSpacing` call
    /// sites) — the Sign In "Having trouble signing in?" heading's updated Figma spec. Uses the
    /// app's existing SF-based approximation approach (see the file-level comment) rather than
    /// GDS Transport, which GOV.UK's Design System restricts to service.gov.uk domains and which
    /// is not bundled in this app — a recorded deviation (see docs/design-specs/sign-in.md).
    static let troubleHeading = Font.system(size: 24, weight: .bold)
}
