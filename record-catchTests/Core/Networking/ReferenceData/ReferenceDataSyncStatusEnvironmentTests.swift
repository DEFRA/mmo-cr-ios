//
//  ReferenceDataSyncStatusEnvironmentTests.swift
//  record-catchTests
//
//  Covers `StubReferenceDataSyncStatusObserver` (the preview/test double for
//  `ReferenceDataSyncStatusObserving`) and its SwiftUI environment key round-trip. The real
//  `ReferenceDataSyncCoordinator` conformance is covered in its own right by
//  `ReferenceDataSyncCoordinatorTests`.
//

import SwiftUI
import XCTest
@testable import record_catch

@MainActor
final class ReferenceDataSyncStatusEnvironmentTests: XCTestCase {

    func test_init_defaultsToIdle() {
        let sut = StubReferenceDataSyncStatusObserver()

        XCTAssertEqual(sut.status, .idle)
        XCTAssertEqual(sut.retryCallCount, 0)
        XCTAssertEqual(sut.dismissCallCount, 0)
    }

    func test_init_withExplicitStatus_usesIt() {
        let sut = StubReferenceDataSyncStatusObserver(status: .failed(hasLocalData: true))

        XCTAssertEqual(sut.status, .failed(hasLocalData: true))
    }

    func test_retry_incrementsCallCount_withoutChangingStatus() {
        let sut = StubReferenceDataSyncStatusObserver(status: .failed(hasLocalData: false))

        sut.retry()

        XCTAssertEqual(sut.retryCallCount, 1)
        XCTAssertEqual(sut.status, .failed(hasLocalData: false))
    }

    func test_dismissError_incrementsCallCount_andResetsStatusToIdle() {
        let sut = StubReferenceDataSyncStatusObserver(status: .failed(hasLocalData: true))

        sut.dismissError()

        XCTAssertEqual(sut.dismissCallCount, 1)
        XCTAssertEqual(sut.status, .idle)
    }

    func test_environmentValues_defaultsToNil() {
        let environment = EnvironmentValues()

        XCTAssertNil(environment.referenceDataSyncStatus)
    }

    func test_environmentValues_getSet_roundTrips() {
        var environment = EnvironmentValues()
        let observer = StubReferenceDataSyncStatusObserver(status: .syncing)

        environment.referenceDataSyncStatus = observer

        XCTAssertTrue(environment.referenceDataSyncStatus === observer)
    }
}
