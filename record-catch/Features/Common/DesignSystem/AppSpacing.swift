import Foundation
import SwiftUI

enum AppSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum AppControlSize {
    /// WCAG 2.2 (2.5.8) / Apple HIG minimum interactive target size.
    static let minTapTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 44
    static let dateFieldHeight: CGFloat = 44
    static let dateFieldShortWidth: CGFloat = 42
    static let dateFieldYearWidth: CGFloat = 64
}
