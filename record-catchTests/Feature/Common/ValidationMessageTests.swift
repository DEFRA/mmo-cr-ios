import XCTest
@testable import record_catch

@MainActor
final class ValidationMessageTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func test_init_withoutArguments_defaultsToEmptyArguments() {
        let message = ValidationMessage("catchRecord.species.add.validation.enter")

        XCTAssertEqual(message.key, "catchRecord.species.add.validation.enter")
        XCTAssertEqual(message.arguments, [])
    }

    func test_init_withArguments_storesThem() {
        let message = ValidationMessage(
            "catchRecord.species.weight.validation.wholeNumber",
            arguments: ["Atlantic cod (COD)"]
        )

        XCTAssertEqual(message.arguments, ["Atlantic cod (COD)"])
    }

    func test_equatable_matchesSameKeyAndArguments() {
        let first = ValidationMessage("key", arguments: ["a"])
        let second = ValidationMessage("key", arguments: ["a"])
        let different = ValidationMessage("key", arguments: ["b"])

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func test_localized_withoutArguments_resolvesBareKey() {
        // `record_catch.` qualification is required here: `AppLanguageStore.swift` is also
        // compiled directly into this test target (see the project's membership exceptions,
        // mirrored by the dual-target note on `SearchDropdownField`/`TextInputField`), so an
        // unqualified `AppLanguageStore` would resolve to that copy — which doesn't see this
        // extension, since `ValidationMessage.swift` isn't part of that duplicated set.
        let sut = record_catch.AppLanguageStore(defaults: makeDefaults())
        let message = ValidationMessage("catchRecord.species.add.validation.enter")

        let resolved: String = sut.localized(message)
        XCTAssertEqual(resolved, "Enter the species you want to add")
    }

    func test_localized_withArguments_substitutesThem() {
        let sut = record_catch.AppLanguageStore(defaults: makeDefaults())
        let message = ValidationMessage(
            "catchRecord.species.weight.validation.wholeNumber",
            arguments: ["Atlantic cod (COD)"]
        )

        let resolved: String = sut.localized(message)
        XCTAssertEqual(resolved, "Weight for Atlantic cod (COD) must be a whole number")
    }
}
