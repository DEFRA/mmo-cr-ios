import XCTest
@testable import record_catch

@MainActor
final class RemoveSpeciesViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let cod = SpeciesOption(name: "Atlantic cod (COD)")
    private let bass = SpeciesOption(name: "Seabass (BSS)")

    private func makeSUT(
        gear: GearOption = .seineNets,
        recordedSpecies: [SpeciesOption],
        router: CatchRecordRouter,
        draft: CatchRecordDraft? = nil
    ) -> (sut: RemoveSpeciesViewModel, router: CatchRecordRouter, draft: CatchRecordDraft) {
        let draft = draft ?? {
            let draft = CatchRecordDraft()
            draft.gearCatches = [GearCatch(gear: gear, speciesCaught: recordedSpecies)]
            return draft
        }()
        let sut = RemoveSpeciesViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            draft: draft
        )
        return (sut, router, draft)
    }

    // MARK: - Loading

    func test_init_loadsThisGearsRecordedSpecies() {
        let (sut, _, _) = makeSUT(recordedSpecies: [cod, bass], router: CatchRecordRouter())

        XCTAssertEqual(sut.species.map(\.id), [cod.id, bass.id])
    }

    func test_init_withMultipleGears_loadsOnlyMatchingGearsSpecies() {
        let trawl = GearOption(name: "Trawl nets")
        let draft = CatchRecordDraft()
        draft.gearCatches = [
            GearCatch(gear: .seineNets, speciesCaught: [cod]),
            GearCatch(gear: trawl, speciesCaught: [bass])
        ]
        let sut = RemoveSpeciesViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: draft
        )

        XCTAssertEqual(sut.species.map(\.id), [cod.id])
    }

    // MARK: - Selection

    func test_toggleSelection_addsAndRemovesID() {
        let (sut, _, _) = makeSUT(recordedSpecies: [cod, bass], router: CatchRecordRouter())

        sut.toggleSelection(cod.id)
        XCTAssertTrue(sut.isSelected(cod.id))

        sut.toggleSelection(cod.id)
        XCTAssertFalse(sut.isSelected(cod.id))
    }

    func test_toggleSelection_clearsExistingValidationError() {
        let (sut, _, _) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        sut.delete()
        XCTAssertNotNil(sut.errorKey)

        sut.toggleSelection(cod.id)

        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Delete validation

    func test_delete_withNoSelection_setsErrorKey_andDoesNotShowConfirmation() {
        let (sut, _, _) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())

        sut.delete()

        XCTAssertEqual(sut.errorKey, "catchRecord.species.remove.error")
        XCTAssertFalse(sut.showDeleteConfirmation)
    }

    func test_delete_withSelection_showsConfirmation_andClearsError() {
        let (sut, _, _) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)

        sut.delete()

        XCTAssertTrue(sut.showDeleteConfirmation)
        XCTAssertNil(sut.errorKey)
    }

    func test_cancelDelete_dismissesConfirmation_withoutMutatingDraft() {
        let (sut, router, draft) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.delete()

        sut.cancelDelete()

        XCTAssertFalse(sut.showDeleteConfirmation)
        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [cod.id])
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - Confirm delete (species remain)

    func test_confirmDelete_whenSpeciesRemain_removesOnlyTickedFromDraft() {
        let (sut, _, draft) = makeSUT(recordedSpecies: [cod, bass], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.delete()

        sut.confirmDelete()

        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [bass.id])
        XCTAssertEqual(sut.species.map(\.id), [bass.id])
    }

    func test_confirmDelete_whenSpeciesRemain_pushesRecordSpeciesWeights() {
        let (sut, router, _) = makeSUT(recordedSpecies: [cod, bass], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.delete()

        sut.confirmDelete()

        XCTAssertEqual(
            router.path,
            [.recordSpeciesWeights(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    // MARK: - Confirm delete (last species removed)

    func test_confirmDelete_whenLastSpeciesRemoved_emptiesDraftsSpeciesCaught() {
        let (sut, _, draft) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.delete()

        sut.confirmDelete()

        XCTAssertTrue(draft.gearCatches.first?.speciesCaught.isEmpty ?? false)
    }

    func test_confirmDelete_whenLastSpeciesRemoved_pushesAddSpecies_withRecordWeightsReturnPhase() {
        let (sut, router, _) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.delete()

        sut.confirmDelete()

        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }

    func test_confirmDelete_removingMultipleTickedSpecies_leavesOnlyUntickedBehind() {
        let herring = SpeciesOption(name: "Herring (HER)")
        let (sut, _, draft) = makeSUT(recordedSpecies: [cod, bass, herring], router: CatchRecordRouter())
        sut.toggleSelection(cod.id)
        sut.toggleSelection(bass.id)
        sut.delete()

        sut.confirmDelete()

        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [herring.id])
    }

    // MARK: - Cancel

    func test_cancel_popsRouter_withoutMutatingDraft() {
        let (sut, router, draft) = makeSUT(recordedSpecies: [cod], router: CatchRecordRouter())
        router.push(.removeSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber))

        sut.cancel()

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [cod.id])
    }
}
