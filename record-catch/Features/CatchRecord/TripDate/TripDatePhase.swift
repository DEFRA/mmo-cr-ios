import Foundation

/// Which trip date the reusable `TripDateView` is collecting.
///
/// Drives the screen's heading, accessibility identifiers and the next route so a single
/// View/ViewModel serves both the "trip departure" and "trip return" variants of the design.
nonisolated enum TripDatePhase: Hashable {
    /// "When did you leave for your trip?"
    case departure
    /// "When did you return from your trip?"
    case `return`

    /// String Catalog key for the screen's H1.
    var titleKey: String {
        switch self {
        case .departure: return "catchRecord.tripDate.departure.title"
        case .return: return "catchRecord.tripDate.return.title"
        }
    }

    /// Stable identifier fragment used to compose accessibility identifiers.
    var accessibilityIdentifierFragment: String {
        switch self {
        case .departure: return "departure"
        case .return: return "return"
        }
    }
}
