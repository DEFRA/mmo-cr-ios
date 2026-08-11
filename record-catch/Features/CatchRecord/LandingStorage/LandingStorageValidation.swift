import Foundation

/// Whether any catch from this trip will not be landed straight away (e.g. bait or keep pots).
enum LandingStorageOption: String, CaseIterable, Identifiable {
    case yes
    case no

    var id: String { rawValue }
}

/// Pure, static validation for the "Is there any catch you will not be landing straight away?" screen.
enum LandingStorageValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `selection` is valid.
    static func errorKey(for selection: LandingStorageOption?) -> String? {
        selection == nil ? "catchRecord.landingStorage.validation.none" : nil
    }
}
