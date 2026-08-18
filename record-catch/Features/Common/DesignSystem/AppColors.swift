import SwiftUI

enum AppColors {
    static let govBlue = Color(red: 0.0, green: 0.37, blue: 0.65)
    static let govGreen = Color(red: 0.0, green: 0.44, blue: 0.24)
    static let govYellow = Color(red: 1.0, green: 0.87, blue: 0.0)
    static let errorRed = Color(red: 0.831, green: 0.208, blue: 0.110)

    static let textPrimary = Color.black
    static let textSecondary = Color(red: 0.31, green: 0.31, blue: 0.31)
    static let borderDefault = Color(red: 0.54, green: 0.54, blue: 0.54)
    static let borderStrong = Color.black
    static let background = Color.white
    static let surfaceMuted = Color(red: 0.97, green: 0.97, blue: 0.97)

    static let linkText = govBlue
    static let divider = Color(red: 0.82, green: 0.82, blue: 0.82)

    // MARK: - TabBar
    //
    // The Figma design's literal unselected-tab grey (`#B1B4B6`) is ~2.3:1 against white and
    // fails WCAG 2.2 AA text contrast (4.5:1). Per the non-negotiable accessibility override in
    // the working framework, we deviate from the literal design value and reuse the existing,
    // already-verified `textSecondary` token instead (see ADR-0006 / settings.md deviation #2).
    static let tabItemSelected = govBlue
    static let tabItemUnselected = textSecondary

    static let statusSubmittedBackground = Color(red: 0.81, green: 0.91, blue: 0.87)
    static let statusSubmittedText = Color(red: 0.0, green: 0.31, blue: 0.21)
    static let statusAmendedBackground = Color(red: 0.80, green: 0.87, blue: 0.95)
    static let statusAmendedText = Color(red: 0.08, green: 0.22, blue: 0.42)
    static let statusUnsentBackground = Color(red: 1.0, green: 0.93, blue: 0.62)
    static let statusUnsentText = Color(red: 0.36, green: 0.24, blue: 0.0)
    static let statusLateBackground = Color(red: 0.96, green: 0.86, blue: 0.86)
    static let statusLateText = Color(red: 0.49, green: 0.0, blue: 0.0)
}
