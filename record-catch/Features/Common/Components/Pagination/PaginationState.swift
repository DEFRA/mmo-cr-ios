import Foundation

/// Pure, SwiftUI-free model backing the GDS-style pagination control.
///
/// Owns the derivable presentation logic — the "showing X to Y of Z" range,
/// the visible page numbers (with an ellipsis rule for long ranges) and the
/// previous/next availability — so it can be unit tested without a view host.
struct PaginationState: Equatable {

    /// A rendered slot in the page-number strip.
    enum PageItem: Equatable {
        case page(Int)
        case ellipsis
    }

    /// The 1-based index of the current page.
    let currentPage: Int
    /// The total number of pages (>= 1).
    let totalPages: Int
    /// The number of items shown per page (> 0).
    let pageSize: Int
    /// The total number of items across all pages (>= 0).
    let totalItems: Int

    init(currentPage: Int, totalPages: Int, pageSize: Int, totalItems: Int) {
        self.totalPages = max(1, totalPages)
        self.currentPage = min(max(1, currentPage), max(1, totalPages))
        self.pageSize = max(1, pageSize)
        self.totalItems = max(0, totalItems)
    }

    /// The 1-based index of the first item shown on the current page.
    var firstItemOnPage: Int {
        totalItems == 0 ? 0 : ((currentPage - 1) * pageSize) + 1
    }

    /// The 1-based index of the last item shown on the current page.
    var lastItemOnPage: Int {
        min(currentPage * pageSize, totalItems)
    }

    /// Whether a previous page exists (controls Previous visibility).
    var canGoPrevious: Bool { currentPage > 1 }

    /// Whether a next page exists (controls Next visibility).
    var canGoNext: Bool { currentPage < totalPages }

    /// Builds the "showing" range text using the caller's localised format
    /// (expects three positional `%@` args: first, last, total).
    func showingText(format: String) -> String {
        String(
            format: format,
            String(firstItemOnPage),
            String(lastItemOnPage),
            String(totalItems)
        )
    }

    /// The visible page-number strip, applying an ellipsis rule for long ranges.
    ///
    /// Always shows the first and last page, the current page and its immediate
    /// neighbours; gaps are collapsed to a single `.ellipsis`.
    var pageItems: [PageItem] {
        guard totalPages > 1 else { return [.page(1)] }

        var pages: Set<Int> = [1, totalPages, currentPage]
        pages.insert(max(1, currentPage - 1))
        pages.insert(min(totalPages, currentPage + 1))

        let sorted = pages.sorted()
        var items: [PageItem] = []
        var previous = 0
        for page in sorted {
            if previous != 0 && page - previous > 1 {
                items.append(.ellipsis)
            }
            items.append(.page(page))
            previous = page
        }
        return items
    }
}
