import XCTest
@testable import record_catch

@MainActor
final class SubmissionSuccessViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    func test_referenceNumber_isExposedUnchanged() {
        let sut = SubmissionSuccessViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    func test_viewCatchRecords_popsToRoot() {
        let router = CatchRecordRouter()
        router.startNew()
        router.push(.submissionSuccess(referenceNumber: referenceNumber))
        let sut = SubmissionSuccessViewModel(referenceNumber: referenceNumber, router: router)

        sut.viewCatchRecords()

        XCTAssertTrue(router.path.isEmpty)
    }
}
