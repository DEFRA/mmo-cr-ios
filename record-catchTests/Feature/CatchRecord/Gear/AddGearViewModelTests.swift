import XCTest
@testable import record_catch

@MainActor
final class AddGearViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(router: CatchRecordRouter) -> AddGearViewModel {
        AddGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            gearSearch: StubGearSearchProvider()
        )
    }

    func test_loadGears_populatesGearNames() async {
        let sut = makeSUT(router: CatchRecordRouter())
        await sut.loadGears()
        XCTAssertEqual(sut.gearNames, ["Seine nets (not specified)"])
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        await sut.loadGears()

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.addGear.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withSelection_routesToMeasurements() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        await sut.loadGears()
        sut.selectedName = "Seine nets (not specified)"

        sut.submit()

        XCTAssertEqual(
            router.path,
            [.gearMeasurements(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }
}
