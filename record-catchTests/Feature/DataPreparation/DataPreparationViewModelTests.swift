//
//  DataPreparationViewModelTests.swift
//  record-catchTests
//
//  Covers `DataPreparationViewModel`'s preparing/failed state machine against a fake
//  `ReferenceDataPreparing` (see ADR-0024 "Data before Home") — no real
//  `ReferenceDataSyncService`/`ReferenceDataStore`/network dependencies needed.
//

import XCTest
@testable import record_catch

@MainActor
private final class FakeReferenceDataPreparing: ReferenceDataPreparing {
    var isDeviceOnline: Bool
    var prepareResult: Bool
    private(set) var prepareRequiredDataCallCount = 0
    private(set) var lastTimeout: TimeInterval?

    init(prepareResult: Bool, isDeviceOnline: Bool = true) {
        self.prepareResult = prepareResult
        self.isDeviceOnline = isDeviceOnline
    }

    func prepareRequiredData(timeout: TimeInterval) async -> Bool {
        prepareRequiredDataCallCount += 1
        lastTimeout = timeout
        return prepareResult
    }
}

@MainActor
final class DataPreparationViewModelTests: XCTestCase {

    func test_initialState_isPreparing() {
        let sut = DataPreparationViewModel(
            coordinator: FakeReferenceDataPreparing(prepareResult: true),
            onReady: {},
            onSignOut: {}
        )

        XCTAssertEqual(sut.state, .preparing)
    }

    func test_prepare_whenCoordinatorSucceeds_callsOnReady() async {
        var readyCallCount = 0
        let sut = DataPreparationViewModel(
            coordinator: FakeReferenceDataPreparing(prepareResult: true),
            onReady: { readyCallCount += 1 },
            onSignOut: {}
        )

        await sut.prepare()

        XCTAssertEqual(readyCallCount, 1)
        XCTAssertEqual(sut.state, .preparing, "onReady moves the session phase on; this view model's own state is irrelevant once ready")
    }

    func test_prepare_whenCoordinatorFails_andOnline_setsFailedState_notOffline() async {
        let coordinator = FakeReferenceDataPreparing(prepareResult: false, isDeviceOnline: true)
        let sut = DataPreparationViewModel(coordinator: coordinator, onReady: {}, onSignOut: {})

        await sut.prepare()

        XCTAssertEqual(sut.state, .failed(isOffline: false))
    }

    func test_prepare_whenCoordinatorFails_andOffline_setsFailedState_offline() async {
        let coordinator = FakeReferenceDataPreparing(prepareResult: false, isDeviceOnline: false)
        let sut = DataPreparationViewModel(coordinator: coordinator, onReady: {}, onSignOut: {})

        await sut.prepare()

        XCTAssertEqual(sut.state, .failed(isOffline: true))
    }

    func test_prepare_doesNotCallOnReady_whenCoordinatorFails() async {
        var readyCallCount = 0
        let coordinator = FakeReferenceDataPreparing(prepareResult: false)
        let sut = DataPreparationViewModel(coordinator: coordinator, onReady: { readyCallCount += 1 }, onSignOut: {})

        await sut.prepare()

        XCTAssertEqual(readyCallCount, 0)
    }

    func test_prepare_usesTheSharedTimeoutConstant() async {
        let coordinator = FakeReferenceDataPreparing(prepareResult: true)
        let sut = DataPreparationViewModel(coordinator: coordinator, onReady: {}, onSignOut: {})

        await sut.prepare()

        XCTAssertEqual(coordinator.lastTimeout, DataPreparationViewModel.timeout)
    }

    func test_prepare_calledAgainAfterFailure_resetsStateToPreparing_thenResolves() async {
        let coordinator = FakeReferenceDataPreparing(prepareResult: false)
        let sut = DataPreparationViewModel(coordinator: coordinator, onReady: {}, onSignOut: {})
        await sut.prepare()
        XCTAssertEqual(sut.state, .failed(isOffline: false))

        coordinator.prepareResult = true
        await sut.prepare()

        XCTAssertEqual(coordinator.prepareRequiredDataCallCount, 2)
        XCTAssertEqual(sut.state, .preparing)
    }

    func test_onSignOut_invokesTheInjectedClosure() {
        var signOutCallCount = 0
        let sut = DataPreparationViewModel(
            coordinator: FakeReferenceDataPreparing(prepareResult: true),
            onReady: {},
            onSignOut: { signOutCallCount += 1 }
        )

        sut.onSignOut()

        XCTAssertEqual(signOutCallCount, 1)
    }
}
