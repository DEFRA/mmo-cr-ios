import XCTest
@testable import record_catch

@MainActor
final class PasswordResetRouterTests: XCTestCase {

    func test_initialState_pathIsEmpty() {
        let sut = PasswordResetRouter()
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_start_pushesResetPasswordRoute() {
        let sut = PasswordResetRouter()
        sut.start()
        XCTAssertEqual(sut.path, [.resetPassword(attempt: 1)])
    }

    func test_restart_afterPushingFurther_resetsToFreshResetPasswordRoute() {
        let sut = PasswordResetRouter()
        sut.start()
        sut.push(.enterCode)
        sut.push(.createPassword)

        sut.restart()

        XCTAssertEqual(sut.path, [.resetPassword(attempt: 2)])
    }

    func test_push_appendsRoute() {
        let sut = PasswordResetRouter()
        sut.start()
        sut.push(.enterCode)
        XCTAssertEqual(sut.path, [.resetPassword(attempt: 1), .enterCode])
    }

    func test_pop_removesLastRoute_butNeverEmptiesPastResetPassword() {
        let sut = PasswordResetRouter()
        sut.start()
        sut.push(.enterCode)

        sut.pop()
        XCTAssertEqual(sut.path, [.resetPassword(attempt: 1)])

        sut.pop()
        XCTAssertEqual(sut.path, [.resetPassword(attempt: 1)], "pop() must not empty the router's own root")
    }

    func test_finish_clearsPath() {
        let sut = PasswordResetRouter()
        sut.start()
        sut.push(.enterCode)

        sut.finish()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_setPath_replacesPathDirectly() {
        let sut = PasswordResetRouter()
        sut.setPath([.resetPassword(attempt: 5), .enterCode, .createPassword])
        XCTAssertEqual(sut.path, [.resetPassword(attempt: 5), .enterCode, .createPassword])
    }
}
