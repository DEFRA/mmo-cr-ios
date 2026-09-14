import XCTest
@testable import record_catch

@MainActor
final class HomeViewModelTests: XCTestCase {

    private let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "You")

    private func makeSUT(rows: [record_catch.SubmissionRow] = [], shouldThrow: Bool = false) -> HomeViewModel {
        let provider = StubRecordsProvider(rows: rows, shouldThrow: shouldThrow)
        return HomeViewModel(recordsProvider: provider)
    }

    func test_initialState_isLoading_withNoRows() {
        let sut = makeSUT(rows: [row])
        XCTAssertEqual(sut.loadState, .loading)
        XCTAssertTrue(sut.rows.isEmpty)
    }

    func test_load_withRows_setsLoadedState_andExposesRows() async {
        let sut = makeSUT(rows: [row])

        await sut.load()

        XCTAssertEqual(sut.loadState, .loaded)
        XCTAssertEqual(sut.rows, [row])
    }

    func test_load_withNoRows_setsEmptyState() async {
        let sut = makeSUT()

        await sut.load()

        XCTAssertEqual(sut.loadState, .empty)
        XCTAssertTrue(sut.rows.isEmpty)
    }

    func test_load_whenProviderThrows_setsFailedState() async {
        let sut = makeSUT(shouldThrow: true)

        await sut.load()

        XCTAssertEqual(sut.loadState, .failed)
    }

    func test_load_calledAgainAfterFailure_canRecoverToLoaded() async {
        let sut = makeSUT(rows: [row], shouldThrow: true)
        await sut.load()
        XCTAssertEqual(sut.loadState, .failed)

        let recoveredSUT = makeSUT(rows: [row], shouldThrow: false)
        await recoveredSUT.load()

        XCTAssertEqual(recoveredSUT.loadState, .loaded)
    }
}
