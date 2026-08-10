import Foundation

/// Whether the current trip started and finished today.
enum TripTodayOption: String, CaseIterable, Identifiable {
    case yes
    case no

    var id: String { rawValue }
}

/// Pure, static validation for the "Did your trip start and finish today?" screen.
enum TripTodayValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `selection` is valid.
    static func errorKey(for selection: TripTodayOption?) -> String? {
        selection == nil ? "catchRecord.tripToday.validation.none" : nil
    }
}
