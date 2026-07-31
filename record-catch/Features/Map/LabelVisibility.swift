import Foundation

/// Decides whether subzone labels should be visible at the current zoom level.
enum LabelVisibility {

    /// Labels are shown once the visible map region is zoomed in past this threshold.
    static let latitudeDeltaThreshold: Double = 1

    static func shouldShowLabels(forLatitudeDelta latitudeDelta: Double) -> Bool {
        latitudeDelta < latitudeDeltaThreshold
    }
}
