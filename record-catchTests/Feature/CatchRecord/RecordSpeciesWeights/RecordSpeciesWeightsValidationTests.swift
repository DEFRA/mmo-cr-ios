import XCTest
@testable import record_catch

final class RecordSpeciesWeightsValidationTests: XCTestCase {

    private let cod = SpeciesOption(name: "Atlantic cod (COD)")

    // MARK: - selectionErrorMessage

    func test_selectionErrorMessage_empty_returnsMessage() {
        XCTAssertEqual(
            RecordSpeciesWeightsValidation.selectionErrorMessage(selection: [])?.key,
            "catchRecord.species.record.validation.none"
        )
    }

    func test_selectionErrorMessage_nonEmpty_returnsNil() {
        XCTAssertNil(RecordSpeciesWeightsValidation.selectionErrorMessage(selection: [cod.id]))
    }

    // MARK: - weightErrorMessages

    func test_weightErrorMessages_tickedSpeciesWithBlankAbove_returnsEnterError() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [:], below: [:], discarded: [:], belowRevealed: [], discardedRevealed: []
            )
        )
        XCTAssertEqual(
            errors[SpeciesFieldKey(speciesID: cod.id, field: .above)]?.key,
            "catchRecord.species.weight.validation.enter"
        )
    }

    func test_weightErrorMessages_untickedSpecies_isIgnored() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [:], below: [:], discarded: [:], belowRevealed: [], discardedRevealed: []
            )
        )
        XCTAssertTrue(errors.isEmpty)
    }

    func test_weightErrorMessages_validAboveWeight_returnsNoErrors() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [cod.id: "12.5"], below: [:], discarded: [:],
                belowRevealed: [], discardedRevealed: []
            )
        )
        XCTAssertTrue(errors.isEmpty)
    }

    func test_weightErrorMessages_unrevealedBelowField_isNotValidated_evenIfInvalid() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [cod.id: "12.5"], below: [cod.id: "not a number"], discarded: [:],
                belowRevealed: [], discardedRevealed: []
            )
        )
        XCTAssertNil(errors[SpeciesFieldKey(speciesID: cod.id, field: .below)])
    }

    func test_weightErrorMessages_revealedBelowFieldBlank_isValid_becauseOptional() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [cod.id: "12.5"], below: [:], discarded: [:],
                belowRevealed: [cod.id], discardedRevealed: []
            )
        )
        XCTAssertNil(errors[SpeciesFieldKey(speciesID: cod.id, field: .below)])
    }

    func test_weightErrorMessages_revealedBelowFieldInvalid_returnsError() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [cod.id: "12.5"], below: [cod.id: "0"], discarded: [:],
                belowRevealed: [cod.id], discardedRevealed: []
            )
        )
        XCTAssertEqual(
            errors[SpeciesFieldKey(speciesID: cod.id, field: .below)]?.key,
            "catchRecord.species.weight.validation.greaterThanZero"
        )
    }

    func test_weightErrorMessages_revealedDiscardedFieldInvalid_returnsError() {
        let errors = RecordSpeciesWeightsValidation.weightErrorMessages(
            selection: [cod.id],
            species: [cod],
            entries: SpeciesWeightEntries(
                above: [cod.id: "12.5"], below: [:], discarded: [cod.id: "abc"],
                belowRevealed: [], discardedRevealed: [cod.id]
            )
        )
        XCTAssertEqual(
            errors[SpeciesFieldKey(speciesID: cod.id, field: .discarded)]?.key,
            "catchRecord.species.weight.validation.decimalPlace"
        )
    }
}
