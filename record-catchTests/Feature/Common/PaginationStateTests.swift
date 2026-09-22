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

    // MARK: - itemCount-deriving convenience initializer
    //
    // Regression coverage for the bug where Home's pagination control was built from a
    // `totalItems`/`totalPages` pair fixed at view construction, so it never reflected the actual
    // number of drafts/records loaded (see `HomeView.paginationState`). This initializer derives
    // `totalPages` from a live item count instead, so callers can't reintroduce the same bug.

    func testItemCountInit_derivesTotalPages_exactMultipleOfPageSize() {
        let state = PaginationState(currentPage: 1, itemCount: 8, pageSize: 4)
        XCTAssertEqual(state.totalPages, 2)
        XCTAssertEqual(state.totalItems, 8)
    }

    func testItemCountInit_derivesTotalPages_roundsUpPartialLastPage() {
        let state = PaginationState(currentPage: 1, itemCount: 5, pageSize: 4)
        XCTAssertEqual(state.totalPages, 2)
        XCTAssertEqual(state.totalItems, 5)
    }

    func testItemCountInit_growingItemCount_increasesTotalPages() {
        // Simulates a new draft being added to Home's list — the control must grow with it.
        let before = PaginationState(currentPage: 1, itemCount: 4, pageSize: 4)
        let after = PaginationState(currentPage: 1, itemCount: 9, pageSize: 4)
        XCTAssertEqual(before.totalPages, 1)
        XCTAssertEqual(after.totalPages, 3)
    }

    func testItemCountInit_shrinkingItemCount_decreasesTotalPages() {
        // Simulates a draft being deleted — the control must shrink back down, not stay stale.
        let before = PaginationState(currentPage: 3, itemCount: 12, pageSize: 4)
        let after = PaginationState(currentPage: 3, itemCount: 4, pageSize: 4)
        XCTAssertEqual(before.totalPages, 3)
        XCTAssertEqual(after.totalPages, 1)
        // Current page is clamped back into range rather than pointing past the end.
        XCTAssertEqual(after.currentPage, 1)
    }

    func testItemCountInit_zeroItems_yieldsSinglePage() {
        let state = PaginationState(currentPage: 1, itemCount: 0, pageSize: 4)
        XCTAssertEqual(state.totalPages, 1)
        XCTAssertEqual(state.totalItems, 0)
    }

    func testItemCountInit_clampsNegativeItemCountAndPageSize() {
        let state = PaginationState(currentPage: 1, itemCount: -3, pageSize: 0)
        XCTAssertEqual(state.totalItems, 0)
        XCTAssertEqual(state.pageSize, 1)
        XCTAssertEqual(state.totalPages, 1)
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
