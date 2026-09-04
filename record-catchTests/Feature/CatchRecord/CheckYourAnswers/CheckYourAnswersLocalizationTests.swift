import XCTest
@testable import record_catch

/// Verifies the "Check your answers" String Catalog keys resolve to non-empty English strings
/// (mirrors `LocalizedTextTests`'s intent — copy keys must not silently fall through to their
/// raw key or an empty string).
@MainActor
final class CheckYourAnswersLocalizationTests: XCTestCase {

    private let store = AppLanguageStore.preview

    private let keys = [
        "catchRecord.checkYourAnswers.heading",
        "catchRecord.checkYourAnswers.change",
        "catchRecord.checkYourAnswers.change.accessibilityForGear",
        "catchRecord.checkYourAnswers.section.trip",
        "catchRecord.checkYourAnswers.section.speciesNotLanded",
        "catchRecord.checkYourAnswers.label.vessel",
        "catchRecord.checkYourAnswers.label.departureDate",
        "catchRecord.checkYourAnswers.label.returnDate",
        "catchRecord.checkYourAnswers.label.departurePort",
        "catchRecord.checkYourAnswers.label.returnPort",
        "catchRecord.checkYourAnswers.label.statisticalArea",
        "catchRecord.checkYourAnswers.label.gear",
        "catchRecord.checkYourAnswers.label.speciesName",
        "catchRecord.checkYourAnswers.label.weightAbove",
        "catchRecord.checkYourAnswers.label.weightBelow",
        "catchRecord.checkYourAnswers.label.weightDiscarded",
        "catchRecord.checkYourAnswers.label.weightNotLanded"
    ]

    func test_checkYourAnswersKeys_resolveToNonEmptyEnglishStrings() {
        store.language = .english

        for key in keys {
            let resolved = store.localized(key)
            XCTAssertFalse(resolved.isEmpty, "\(key) resolved to an empty string")
            XCTAssertNotEqual(resolved, key, "\(key) did not resolve — fell back to the raw key")
        }
    }
}
