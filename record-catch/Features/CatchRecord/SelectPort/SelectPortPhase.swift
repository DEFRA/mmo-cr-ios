import Foundation

/// Which port the reusable "select favourite port" screen is collecting.
///
/// Drives the screen's heading, hint, validation, accessibility identifiers and the next route so a
/// single View/ViewModel serves both the "Which port did you leave from?" (departure) and "Which
/// port did you return to?" (return) variants of the design — mirroring `TripDatePhase`.
///
/// `nonisolated` so it can appear in `CatchRecordRoute` and be compared in the pure, off-actor
/// routing helpers/tests without introducing main-actor isolation.
nonisolated enum SelectPortPhase: Hashable, Sendable {
    /// "Which port did you leave from?"
    case departure
    /// "Which port did you return to?"
    case `return`

    /// String Catalog key for the screen's H1.
    var titleKey: String {
        switch self {
        case .departure: return "catchRecord.selectPort.departure.heading"
        case .return: return "catchRecord.selectPort.return.heading"
        }
    }

    /// String Catalog key for the screen's hint paragraph.
    var hintKey: String {
        switch self {
        case .departure: return "catchRecord.selectPort.departure.hint"
        case .return: return "catchRecord.selectPort.return.hint"
        }
    }

    /// String Catalog key for the "no selection" inline validation error.
    var validationKey: String {
        switch self {
        case .departure: return "catchRecord.selectPort.departure.validation.none"
        case .return: return "catchRecord.selectPort.return.validation.none"
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
