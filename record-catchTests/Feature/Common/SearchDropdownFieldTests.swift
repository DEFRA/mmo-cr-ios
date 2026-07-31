import XCTest
@testable import record_catch

final class SearchDropdownFieldTests: XCTestCase {

    private let options = StubPortOptionProvider().options

    func testFilteredOptionsReturnsEmptyWhenBelowMinimumCharacters() {
        let results = SearchDropdownField.filteredOptions(query: "a", minimumCharacters: 2, options: options)

        XCTAssertTrue(results.isEmpty)
    }

    func testFilteredOptionsMatchesCaseInsensitively() {
        let results = SearchDropdownField.filteredOptions(query: "ABER", minimumCharacters: 2, options: options)

        XCTAssertEqual(results, ["Aberdeen"])
    }

    func testFilteredOptionsReturnsAllMatches() {
        let results = SearchDropdownField.filteredOptions(query: "ham", minimumCharacters: 2, options: options)

        XCTAssertEqual(results, ["Brixham", "Shoreham"])
    }

    func testHasValidSelectionReturnsFalseWhenSelectionIsNil() {
        let isValid = SearchDropdownField.hasValidSelection(
            selectedOption: nil,
            query: "Aberdeen",
            options: options
        )

        XCTAssertFalse(isValid)
    }

    func testHasValidSelectionReturnsFalseWhenQueryDiffersFromSelectedOption() {
        let isValid = SearchDropdownField.hasValidSelection(
            selectedOption: "Aberdeen",
            query: "Aber",
            options: options
        )

        XCTAssertFalse(isValid)
    }

    func testHasValidSelectionReturnsFalseWhenSelectionNotInOptions() {
        let isValid = SearchDropdownField.hasValidSelection(
            selectedOption: "Fictional Port",
            query: "Fictional Port",
            options: options
        )

        XCTAssertFalse(isValid)
    }

    func testHasValidSelectionReturnsTrueForExactListSelection() {
        let isValid = SearchDropdownField.hasValidSelection(
            selectedOption: "Aberdeen",
            query: "Aberdeen",
            options: options
        )

        XCTAssertTrue(isValid)
    }
}
