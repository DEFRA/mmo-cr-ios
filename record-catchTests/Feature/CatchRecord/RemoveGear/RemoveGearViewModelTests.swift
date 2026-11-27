import XCTest
@testable import record_catch

/// Favourite-gear provider whose `removeFavourite` always throws, for the removal-failure path.
private struct FailingFavouriteGearProvider: FavouriteGearProviding {
    struct Failure: Error {}
    private let gears: [GearOption]
    init(gears: [GearOption]) { self.gears = gears }
    func favouriteGears() async throws -> [GearOption] { gears }
    func addFavourite(_ gear: GearOption) async throws {}
    func removeFavourite(id: String) async throws { throw Failure() }
}

@MainActor
final class RemoveGearViewModelTests: XCTestCase {

    private let vessel = "OLGA"
    private let referenceNumber = "A1234520260727150815"
    private let seineNets = GearOption.seineNets
    private let trawl = GearOption(id: "OTB", name: "Bottom otter trawl")

    private func makeSUT(
        favourites: [GearOption] = [.seineNets],
        router: CatchRecordRouter,
        draft: CatchRecordDraft = CatchRecordDraft(),
        favouriteGears: FavouriteGearProviding? = nil
    ) -> (sut: RemoveGearViewModel, favouriteGears: FavouriteGearProviding) {
        let provider = favouriteGears ?? StubFavouriteGearProvider(initialFavourites: favourites)
        let sut = RemoveGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: provider,
            draft: draft
        )
        return (sut, provider)
    }

    // MARK: - Loading

    func test_loadFavourites_populatesGears() async {
        let (sut, _) = makeSUT(favourites: [seineNets, trawl], router: CatchRecordRouter())

        await sut.loadFavourites()

        // Favourites are sorted alphabetically by name (see `StubFavouriteGearProvider`), so this
        // compares as a set rather than coupling the test to that ordering.
        XCTAssertEqual(Set(sut.gears.map(\.id)), Set([seineNets.id, trawl.id]))
    }

    func test_loadFavourites_withNoFavourites_isEmpty() async {
        let (sut, _) = makeSUT(favourites: [], router: CatchRecordRouter())

        await sut.loadFavourites()

        XCTAssertTrue(sut.gears.isEmpty)
    }

    // MARK: - Selection

    func test_toggleSelection_addsAndRemovesID() {
        let (sut, _) = makeSUT(router: CatchRecordRouter())

        sut.toggleSelection(seineNets.id)
        XCTAssertTrue(sut.isSelected(seineNets.id))

        sut.toggleSelection(seineNets.id)
        XCTAssertFalse(sut.isSelected(seineNets.id))
    }

    func test_toggleSelection_clearsExistingValidationError() {
        let (sut, _) = makeSUT(router: CatchRecordRouter())
        sut.submit()
        XCTAssertNotNil(sut.errorKey)

        sut.toggleSelection(seineNets.id)

        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Submit validation

    func test_submit_withNoSelection_setsErrorKey_andDoesNotShowConfirmation() {
        let (sut, _) = makeSUT(router: CatchRecordRouter())

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.gear.remove.validation.none")
        XCTAssertFalse(sut.showRemoveConfirmation)
    }

    func test_submit_withSelection_showsConfirmation_andClearsError() {
        let (sut, _) = makeSUT(router: CatchRecordRouter())
        sut.toggleSelection(seineNets.id)

        sut.submit()

        XCTAssertTrue(sut.showRemoveConfirmation)
        XCTAssertNil(sut.errorKey)
    }

    func test_cancelRemove_dismissesConfirmation_withoutRemovingAnything() async {
        let (sut, favourites) = makeSUT(router: CatchRecordRouter())
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        sut.cancelRemove()

        XCTAssertFalse(sut.showRemoveConfirmation)
        let remaining = try? await favourites.favouriteGears()
        XCTAssertEqual(remaining?.map(\.id), [seineNets.id])
    }

    // MARK: - Confirm remove (gears remain)

    func test_confirmRemove_whenGearsRemain_removesOnlyTickedFromFavourites() async {
        let router = CatchRecordRouter()
        let (sut, favourites) = makeSUT(favourites: [seineNets, trawl], router: router)
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        await sut.confirmRemove()

        let remaining = try? await favourites.favouriteGears()
        XCTAssertEqual(remaining?.map(\.id), [trawl.id])
        XCTAssertEqual(sut.gears.map(\.id), [trawl.id])
    }

    func test_confirmRemove_whenGearsRemain_routesToSelectGear() async {
        let router = CatchRecordRouter()
        let (sut, _) = makeSUT(favourites: [seineNets, trawl], router: router)
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        await sut.confirmRemove()

        XCTAssertEqual(router.path, [.selectGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    /// Removing a gear also takes it out of the current trip's already-selected gears, so the
    /// in-progress record never references a favourite that no longer exists.
    func test_confirmRemove_alsoRemovesGearFromCurrentDraftsGearCatches() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: seineNets), GearCatch(gear: trawl)]
        let (sut, _) = makeSUT(favourites: [seineNets, trawl], router: router, draft: draft)
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        await sut.confirmRemove()

        XCTAssertEqual(draft.gearCatches.map(\.gear.id), [trawl.id])
    }

    // MARK: - Confirm remove (last gear removed)

    func test_confirmRemove_whenLastGearRemoved_routesToAddGear() async {
        let router = CatchRecordRouter()
        let (sut, favourites) = makeSUT(favourites: [seineNets], router: router)
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        await sut.confirmRemove()

        let remaining = try? await favourites.favouriteGears()
        XCTAssertTrue(remaining?.isEmpty ?? false)
        XCTAssertEqual(router.path, [.addGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    func test_confirmRemove_removingMultipleTickedGears_leavesOnlyUntickedBehind() async {
        let herring = GearOption(name: "Pots")
        let router = CatchRecordRouter()
        let (sut, favourites) = makeSUT(favourites: [seineNets, trawl, herring], router: router)
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.toggleSelection(trawl.id)
        sut.submit()

        await sut.confirmRemove()

        let remaining = try? await favourites.favouriteGears()
        XCTAssertEqual(remaining?.map(\.id), [herring.id])
    }

    // MARK: - Removal failure

    func test_confirmRemove_whenRemovalFails_setsRemoveFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let (sut, _) = makeSUT(
            router: router,
            favouriteGears: FailingFavouriteGearProvider(gears: [seineNets])
        )
        await sut.loadFavourites()
        sut.toggleSelection(seineNets.id)
        sut.submit()

        await sut.confirmRemove()

        XCTAssertTrue(sut.removeFailed)
        XCTAssertTrue(router.path.isEmpty)
    }
}
