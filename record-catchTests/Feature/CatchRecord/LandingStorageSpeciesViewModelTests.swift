import XCTest
@testable import record_catch

@MainActor
final class LandingStorageSpeciesViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    func test_initialState_hasNoFavouritesOrSelection_exposesReferenceNumber() {
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertTrue(sut.favourites.isEmpty)
        XCTAssertTrue(sut.selection.isEmpty)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
        XCTAssertFalse(sut.saveFailed)
    }

    func test_loadFavourites_loadsList_andSeedsPreviouslyCapturedWeightsFromDraft() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let hake = SpeciesOption(name: "Hake (HKE)")
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod, hake])
        let draft = CatchRecordDraft()
        draft.speciesNotLanded = [cod.withWeights(above: "12", below: nil, discarded: nil)]
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), favouriteSpecies: provider, draft: draft)

        await sut.loadFavourites()

        XCTAssertEqual(sut.favourites.count, 2)
        XCTAssertTrue(sut.isSelected(cod.id))
        XCTAssertFalse(sut.isSelected(hake.id))
        XCTAssertEqual(sut.weightEntries[cod.id], "12")
    }

    /// Regression test: the shared favourites store is also written to by every per-gear catch
    /// screen (`RecordSpeciesWeightsViewModel`), so a species' `weightAboveMinimumKg` there may hold
    /// a *gear's* catch weight rather than this trip-level "not landing straight away" weight. This
    /// screen must not confuse the two.
    func test_loadFavourites_doesNotSeedFromSharedFavouritesStore_evenWhenItCarriesAGearsWeight() async {
        let codWithGearsWeight = SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [codWithGearsWeight])
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), favouriteSpecies: provider, draft: CatchRecordDraft())

        await sut.loadFavourites()

        XCTAssertFalse(sut.isSelected(codWithGearsWeight.id))
        XCTAssertNil(sut.weightEntries[codWithGearsWeight.id])
    }

    func test_toggleSelection_addsThenRemoves() {
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        sut.toggleSelection("COD")
        XCTAssertTrue(sut.isSelected("COD"))
        sut.toggleSelection("COD")
        XCTAssertFalse(sut.isSelected("COD"))
    }

    func test_submit_savesCapturedWeightsForTickedSpecies_andPushesCheckYourAnswers() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let hake = SpeciesOption(name: "Hake (HKE)")
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod, hake])
        let router = CatchRecordRouter()
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: router, favouriteSpecies: provider)
        await sut.loadFavourites()

        sut.toggleSelection(cod.id)
        sut.weightEntries[cod.id] = "8.5"

        await sut.submit()

        XCTAssertFalse(sut.saveFailed)
        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        let saved = try? await provider.favouriteSpecies()
        XCTAssertEqual(saved?.first(where: { $0.id == cod.id })?.weightAboveMinimumKg, "8.5")
    }

    func test_submit_whenSaveFails_setsSaveFailed_andDoesNotRoute() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let provider = FailingFavouriteSpeciesProvider(initialFavourites: [cod])
        let router = CatchRecordRouter()
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: router, favouriteSpecies: provider)
        await sut.loadFavourites()
        sut.toggleSelection(cod.id)

        await sut.submit()

        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - Draft capture

    func test_submit_writesTickedSpeciesWithCapturedWeightsIntoDraftAsSpeciesNotLanded() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let hake = SpeciesOption(name: "Hake (HKE)")
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod, hake])
        let draft = CatchRecordDraft()
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), favouriteSpecies: provider, draft: draft)
        await sut.loadFavourites()
        sut.toggleSelection(cod.id)
        sut.weightEntries[cod.id] = "8.5"

        await sut.submit()

        XCTAssertEqual(draft.speciesNotLanded.count, 1)
        XCTAssertEqual(draft.speciesNotLanded.first?.id, cod.id)
        XCTAssertEqual(draft.speciesNotLanded.first?.weightAboveMinimumKg, "8.5")
    }
}

/// Favourite species provider whose `addFavourite` always throws, to exercise the save-failure path.
private final class FailingFavouriteSpeciesProvider: FavouriteSpeciesProviding, @unchecked Sendable {
    private let favourites: [SpeciesOption]

    init(initialFavourites: [SpeciesOption]) {
        self.favourites = initialFavourites
    }

    func favouriteSpecies() async throws -> [SpeciesOption] { favourites }
    func addFavourite(_ species: SpeciesOption) async throws { throw StubError.saveFailed }
    func removeFavourite(id: String) async throws {}

    enum StubError: Error { case saveFailed }
}
