import XCTest
@testable import record_catch

final class AddSpeciesValidationTests: XCTestCase {

    private let cod = SpeciesOption(name: "Atlantic cod (COD)")

    // MARK: - First-time entry (no favourites yet)

    func test_firstTime_emptyQuery_returnsEnterMessage() {
        XCTAssertEqual(
            AddSpeciesValidation.message(query: "", selectedSpecies: nil, context: .firstTime)?.key,
            "catchRecord.species.add.validation.enter"
        )
    }

    func test_firstTime_typedButNothingSelected_returnsSelectMessage() {
        XCTAssertEqual(
            AddSpeciesValidation.message(query: "cod", selectedSpecies: nil, context: .firstTime)?.key,
            "catchRecord.species.add.validation.select"
        )
    }

    func test_firstTime_validSelection_returnsNil() {
        XCTAssertNil(AddSpeciesValidation.message(query: cod.name, selectedSpecies: cod, context: .firstTime))
    }

    // MARK: - Adding another species mid-trip

    func test_addAnother_emptyQuery_returnsEnterMessage() {
        XCTAssertEqual(
            AddSpeciesValidation.message(query: "", selectedSpecies: nil, context: .addAnother)?.key,
            "catchRecord.species.trip.validation.enter"
        )
    }

    func test_addAnother_typedButNothingSelected_returnsSelectMessage() {
        XCTAssertEqual(
            AddSpeciesValidation.message(query: "cod", selectedSpecies: nil, context: .addAnother)?.key,
            "catchRecord.species.trip.validation.select"
        )
    }

    func test_addAnother_validSelection_returnsNil() {
        XCTAssertNil(AddSpeciesValidation.message(query: cod.name, selectedSpecies: cod, context: .addAnother))
    }

    // MARK: - Whitespace-only query is treated as empty

    func test_whitespaceOnlyQuery_returnsEnterMessage() {
        XCTAssertEqual(
            AddSpeciesValidation.message(query: "   ", selectedSpecies: nil, context: .firstTime)?.key,
            "catchRecord.species.add.validation.enter"
        )
    }
}
