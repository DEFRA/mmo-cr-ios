import SwiftUI

enum AppTypography {
    // SF-based approximation of GOV.UK typography scale.
    static let pageCaption = Font.system(size: 24, weight: .regular)
    static let pageTitle = Font.system(size: 34, weight: .bold)
    static let body = Font.system(size: 19, weight: .regular)
    static let bodySmall = Font.system(size: 16, weight: .regular)
    static let button = Font.system(size: 19, weight: .semibold)
    static let fieldLabel = Font.system(size: 16, weight: .regular)
    static let hint = Font.system(size: 16, weight: .regular)
    static let error = Font.system(size: 16, weight: .semibold)
    static let headerTitle = Font.system(size: 20, weight: .bold)
    static let footerHeading = Font.system(size: 17, weight: .semibold)
}
