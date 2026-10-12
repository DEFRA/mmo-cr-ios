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

    // MARK: - Pagination

    private func makeRows(_ count: Int) -> [record_catch.SubmissionRow] {
        (1...count).map { index in
            record_catch.SubmissionRow(
                dateText: "20 Nov 2020",
                vesselName: "ACHILLES \(index)",
                status: .submitted,
                createdBy: "J.Smith"
            )
        }
    }

    func test_load_with6Rows_pageSize4_showsFirstFourRows() async {
        let sut = HomeViewModel(recordsProvider: StubRecordsProvider(rows: makeRows(6)), pageSize: 4)

        await sut.load()

        XCTAssertEqual(sut.pagedRows.count, 4)
        XCTAssertEqual(sut.pagedRows, Array(sut.rows.prefix(4)))
        XCTAssertEqual(sut.paginationState.totalPages, 2)
        XCTAssertEqual(sut.paginationState.showingText(format: "Showing %@ to %@ of %@"), "Showing 1 to 4 of 6")
    }

    func test_goToNext_showsRemainingRows_andUpdatesShowingRange() async {
        let sut = HomeViewModel(recordsProvider: StubRecordsProvider(rows: makeRows(6)), pageSize: 4)
        await sut.load()

        sut.goToNext()

        XCTAssertEqual(sut.currentPage, 2)
        XCTAssertEqual(sut.pagedRows.count, 2)
        XCTAssertEqual(sut.pagedRows, Array(sut.rows.suffix(2)))
        XCTAssertEqual(sut.paginationState.showingText(format: "Showing %@ to %@ of %@"), "Showing 5 to 6 of 6")
        XCTAssertFalse(sut.paginationState.canGoNext)
    }

    func test_goToPage_outOfBounds_isClamped() async {
        let sut = HomeViewModel(recordsProvider: StubRecordsProvider(rows: makeRows(6)), pageSize: 4)
        await sut.load()

        sut.goToPage(99)
        XCTAssertEqual(sut.currentPage, 2)

        sut.goToPage(0)
        XCTAssertEqual(sut.currentPage, 1)
    }

    func test_goToPrevious_onFirstPage_doesNothing() async {
        let sut = HomeViewModel(recordsProvider: StubRecordsProvider(rows: makeRows(6)), pageSize: 4)
        await sut.load()

        sut.goToPrevious()

        XCTAssertEqual(sut.currentPage, 1)
    }

    func test_load_afterRowsShrink_clampsCurrentPageIntoRange() async {
        var rows = makeRows(6)
        let provider = MutableStubRecordsProvider(rows: rows)
        let sut = HomeViewModel(recordsProvider: provider, pageSize: 4)
        await sut.load()
        sut.goToNext()
        XCTAssertEqual(sut.currentPage, 2)

        rows = makeRows(2)
        provider.rows = rows
        await sut.load()

        XCTAssertEqual(sut.currentPage, 1)
        XCTAssertEqual(sut.pagedRows.count, 2)
    }

    func test_pagedRows_whenEmpty_returnsEmpty() async {
        let sut = HomeViewModel(recordsProvider: StubRecordsProvider(rows: []), pageSize: 4)

        await sut.load()

        XCTAssertEqual(sut.pagedRows, [])
    }
}
