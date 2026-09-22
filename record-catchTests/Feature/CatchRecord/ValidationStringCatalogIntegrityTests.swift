//
//  ValidationStringCatalogIntegrityTests.swift
//  record-catchTests
//
//  Guards against a missed or malformed translation for the validation-copy work: every key
//  introduced or re-worded for the catch-record validation messages must resolve to a real
//  value in both English and Welsh, not fall back to the raw key. `LocalizedBundle.string(_:)`
//  returns the key itself when a translation is missing (see `LocalizedBundle.swift`), so
//  asserting the resolved value != the key is a reliable, cheap completeness check that doesn't
//  need to parse the source `.xcstrings` file directly.
//
//  This does not assert translation *quality* (that's a human review concern, tracked via the
//  `needs_review` state in the catalog) — only that a value exists for both locales.

import XCTest
@testable import record_catch

@MainActor
final class ValidationStringCatalogIntegrityTests: XCTestCase {

    /// Every key added or re-worded as part of the catch-record validation-copy change.
    private static let keysUnderTest: [String] = [
        // Copy-only screens (Task 4A–4F)
        "catchRecord.draftAction.validation.none",
        "catchRecord.addGear.validation.none",
        "catchRecord.selectGear.validation.none",
        "catchRecord.catchLocation.validation.none",
        "catchRecord.landingStorage.validation.none",
        "catchRecord.addPort.validation.none",

        // Trip date (Task 5–6). Per-field "missing"/"not a real date"/"future"/"before
        // departure" validation keys were removed as part of ADR-0017 (native `DatePicker`
        // replacing the day/month/year `DateEntryField`): `TripDateViewModel.selectableRange`
        // clamps out every invalid value, so those states can no longer occur and their copy
        // keys were retired along with `TripDateValidation`. Only the (still-shown) hints
        // remain under test here.
        "catchRecord.tripDate.departure.hint",
        "catchRecord.tripDate.return.hint",

        // Species (Task 7a)
        "catchRecord.species.add.validation.enter",
        "catchRecord.species.add.validation.select",
        "catchRecord.species.trip.validation.enter",
        "catchRecord.species.trip.validation.select",
        "catchRecord.species.record.validation.none",

        // Weights (Task 7b–7d)
        "catchRecord.species.weight.validation.enter",
        "catchRecord.species.weight.validation.decimalPlace",
        "catchRecord.species.weight.validation.wholeNumber",
        "catchRecord.species.weight.validation.greaterThanZero",
        "catchRecord.landingStorageSpecies.weight.validation.enter",

        // Error summary (Task 9)
        "catchRecord.errorSummary.title"
    ]

    func test_everyValidationKey_resolvesInEnglish() {
        let sut = AppLanguageStore(defaults: makeDefaults())
        for key in Self.keysUnderTest {
            let value = sut.localized(key)
            XCTAssertNotEqual(value, key, "Missing English translation for key '\(key)'")
        }
    }

    func test_everyValidationKey_resolvesInWelsh() {
        let sut = AppLanguageStore(defaults: makeDefaults())
        sut.toggle() // Welsh
        for key in Self.keysUnderTest {
            let value = sut.localized(key)
            XCTAssertNotEqual(value, key, "Missing Welsh translation for key '\(key)'")
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
