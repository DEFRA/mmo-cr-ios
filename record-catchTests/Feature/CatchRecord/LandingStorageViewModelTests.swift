import XCTest
@testable import record_catch

@MainActor
final class LandingStorageViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    func test_initialState_hasNoSelectionAndNoError_exposesReferenceNumber() {
        let sut = LandingStorageViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = LandingStorageViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        sut.selection = nil
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = LandingStorageViewModel(referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.landingStorage.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withYesSelected_clearsError_andPushesLandingStorageSpecies() {
        let router = CatchRecordRouter()
        let sut = LandingStorageViewModel(referenceNumber: referenceNumber, router: router)
        sut.selection = .yes

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.landingStorageSpecies(referenceNumber: referenceNumber)])
    }

    func test_submit_withNoSelected_pushesCheckYourAnswers() {
        let router = CatchRecordRouter()
        let sut = LandingStorageViewModel(referenceNumber: referenceNumber, router: router)
        sut.selection = .no

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
    }
}
