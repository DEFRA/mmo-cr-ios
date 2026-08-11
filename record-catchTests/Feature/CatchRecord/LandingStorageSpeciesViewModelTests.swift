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

    func test_loadFavourites_loadsList_andSeedsPreviouslyCapturedWeights() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "12", below: nil, discarded: nil)
        let hake = SpeciesOption(name: "Hake (HKE)")
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod, hake])
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter(), favouriteSpecies: provider)

        await sut.loadFavourites()

        XCTAssertEqual(sut.favourites.count, 2)
        XCTAssertTrue(sut.isSelected(cod.id))
        XCTAssertFalse(sut.isSelected(hake.id))
        XCTAssertEqual(sut.weightEntries[cod.id], "12")
    }

    func test_toggleSelection_addsThenRemoves() {
        let sut = LandingStorageSpeciesViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        sut.toggleSelection("COD")
        XCTAssertTrue(sut.isSelected("COD"))
        sut.toggleSelection("COD")
        XCTAssertFalse(sut.isSelected("COD"))
    }

    func test_submit_savesCapturedWeightsForTickedSpecies_andPushesPlaceholderNextStep() async {
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
        XCTAssertEqual(router.path, [.placeholderNextStep])
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
