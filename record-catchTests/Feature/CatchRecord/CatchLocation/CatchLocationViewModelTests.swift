import XCTest
@testable import record_catch

@MainActor
final class CatchLocationViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(router: CatchRecordRouter) -> CatchLocationViewModel {
        CatchLocationViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.catchLocation.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withEmptySelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selectedArea = ""

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.catchLocation.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withSelection_routesToNextStep() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selectedArea = "38E96"

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.placeholderNextStep])
    }
}
