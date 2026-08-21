import XCTest
@testable import record_catch

@MainActor
final class SettingsRouterTests: XCTestCase {

    func test_init_pathIsEmpty() {
        let sut = SettingsRouter()
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_push_appendsRoute() {
        let sut = SettingsRouter()

        sut.push(.manageAccount)

        XCTAssertEqual(sut.path, [.manageAccount])
    }

    func test_pop_removesTopRoute_returningToPreviousScreen() {
        let sut = SettingsRouter()
        sut.push(.manageAccount)

        sut.pop()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_pop_whenAtRoot_isNoOp() {
        let sut = SettingsRouter()

        sut.pop()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_popToRoot_clearsPath() {
        let sut = SettingsRouter()
        sut.push(.manageAccount)

        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_setPath_replacesWholePath() {
        let sut = SettingsRouter()

        sut.setPath([.manageAccount])

        XCTAssertEqual(sut.path, [.manageAccount])
    }

    func test_canGoBack_isFalse_whenPathEmpty() {
        let sut = SettingsRouter()
        XCTAssertFalse(sut.canGoBack)
    }

    func test_canGoBack_isTrue_whenPathNonEmpty() {
        let sut = SettingsRouter()
        sut.push(.manageAccount)
        XCTAssertTrue(sut.canGoBack)
    }
}
