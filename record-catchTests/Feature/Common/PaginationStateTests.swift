import XCTest
@testable import record_catch

final class PaginationStateTests: XCTestCase {

    private let format = "Showing %1$@ to %2$@ of %3$@"

    // MARK: - Range text

    func testShowingText_singleFullPage() {
        let state = PaginationState(currentPage: 1, totalPages: 1, pageSize: 4, totalItems: 4)
        XCTAssertEqual(state.showingText(format: format), "Showing 1 to 4 of 4")
    }

    func testShowingText_middlePage() {
        let state = PaginationState(currentPage: 2, totalPages: 3, pageSize: 10, totalItems: 25)
        XCTAssertEqual(state.showingText(format: format), "Showing 11 to 20 of 25")
    }

    func testShowingText_lastPartialPage() {
        let state = PaginationState(currentPage: 3, totalPages: 3, pageSize: 10, totalItems: 25)
        XCTAssertEqual(state.showingText(format: format), "Showing 21 to 25 of 25")
    }

    func testShowingText_noItems() {
        let state = PaginationState(currentPage: 1, totalPages: 1, pageSize: 10, totalItems: 0)
        XCTAssertEqual(state.firstItemOnPage, 0)
        XCTAssertEqual(state.lastItemOnPage, 0)
        XCTAssertEqual(state.showingText(format: format), "Showing 0 to 0 of 0")
    }

    // MARK: - Edge cases / clamping

    func testInit_clampsCurrentPageWithinBounds() {
        XCTAssertEqual(PaginationState(currentPage: 0, totalPages: 3, pageSize: 4, totalItems: 12).currentPage, 1)
        XCTAssertEqual(PaginationState(currentPage: 99, totalPages: 3, pageSize: 4, totalItems: 12).currentPage, 3)
    }

    func testInit_clampsTotalPagesAndPageSizeToAtLeastOne() {
        let state = PaginationState(currentPage: 1, totalPages: 0, pageSize: 0, totalItems: -5)
        XCTAssertEqual(state.totalPages, 1)
        XCTAssertEqual(state.pageSize, 1)
        XCTAssertEqual(state.totalItems, 0)
    }

    // MARK: - Previous / next availability

    func testCanGoPreviousNext_firstPage() {
        let state = PaginationState(currentPage: 1, totalPages: 3, pageSize: 4, totalItems: 12)
        XCTAssertFalse(state.canGoPrevious)
        XCTAssertTrue(state.canGoNext)
    }

    func testCanGoPreviousNext_lastPage() {
        let state = PaginationState(currentPage: 3, totalPages: 3, pageSize: 4, totalItems: 12)
        XCTAssertTrue(state.canGoPrevious)
        XCTAssertFalse(state.canGoNext)
    }

    func testCanGoPreviousNext_singlePageHidesBoth() {
        let state = PaginationState(currentPage: 1, totalPages: 1, pageSize: 4, totalItems: 4)
        XCTAssertFalse(state.canGoPrevious)
        XCTAssertFalse(state.canGoNext)
    }

    // MARK: - Page items / ellipsis rule

    func testPageItems_singlePage() {
        let state = PaginationState(currentPage: 1, totalPages: 1, pageSize: 4, totalItems: 4)
        XCTAssertEqual(state.pageItems, [.page(1)])
    }

    func testPageItems_shortRangeHasNoEllipsis() {
        let state = PaginationState(currentPage: 2, totalPages: 3, pageSize: 4, totalItems: 12)
        XCTAssertEqual(state.pageItems, [.page(1), .page(2), .page(3)])
    }

    func testPageItems_longRangeInsertsEllipsisOnBothSides() {
        let state = PaginationState(currentPage: 5, totalPages: 10, pageSize: 4, totalItems: 40)
        XCTAssertEqual(
            state.pageItems,
            [.page(1), .ellipsis, .page(4), .page(5), .page(6), .ellipsis, .page(10)]
        )
    }

    func testPageItems_nearStartCollapsesTrailingGapOnly() {
        let state = PaginationState(currentPage: 2, totalPages: 10, pageSize: 4, totalItems: 40)
        XCTAssertEqual(
            state.pageItems,
            [.page(1), .page(2), .page(3), .ellipsis, .page(10)]
        )
    }
}
