import Foundation

/// View model for the "Where was most of your catch caught using <gear>?" screen.
///
/// The user picks a single statistical area (subzone) on the map. On "Save and continue" the
/// selection is validated (an area must be chosen) and the journey routes on. UI-only for this
/// phase: the chosen area is threaded no further than the placeholder next step, and the map is
/// the existing `SeaMapView` component (its style need not match the design).
@MainActor
@Observable
final class CatchLocationViewModel {

    /// The gear this location applies to — supplies the "using <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward unchanged.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The statistical area (subzone code) tapped on the map, or `nil` until one is chosen.
    var selectedArea: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return CatchLocationValidation.errorKey(for: selectedArea)
    }

    /// Validates "Save and continue" and routes on when an area has been selected.
    func submit() {
        didAttemptSubmit = true
        guard CatchLocationValidation.errorKey(for: selectedArea) == nil else { return }
        router.push(.placeholderNextStep)
    }
}
