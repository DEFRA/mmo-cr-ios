//
//  DataPreparationViewModel.swift
//  record-catch
//
//  Drives the "Downloading data" screen shown between sign-in/unlock and Home (see
//  `RootPhase.preparingData`, ADR-0024 "Data before Home"). No picker screen is reachable until
//  the required reference data (ports/species/gears) is present on-device, so this view model
//  blocks on a sync and reports a retryable failure — with an offline-specific message — if it
//  can't be satisfied.
//

import Foundation

/// Narrow seam over `ReferenceDataSyncCoordinator` (mirrors `ReferenceDataSyncStatusObserving`'s
/// role for `SyncErrorBanner`), so this view model is unit-testable without the real
/// coordinator's `ReferenceDataSyncService`/`ReferenceDataStore`/network dependencies.
@MainActor
protocol ReferenceDataPreparing: AnyObject {
    var isDeviceOnline: Bool { get }
    func prepareRequiredData(timeout: TimeInterval) async -> Bool
}

extension ReferenceDataSyncCoordinator: ReferenceDataPreparing {}

@MainActor
@Observable
final class DataPreparationViewModel {

    enum State: Equatable {
        case preparing
        /// `isOffline` distinguishes "connect to the internet to continue" from a generic
        /// "something went wrong, try again" message — the device's connectivity at the moment
        /// preparation gave up, not necessarily the whole time it was trying.
        case failed(isOffline: Bool)
    }

    /// How long a single preparation attempt waits for the sync before giving up and re-checking
    /// on-device state (see `ReferenceDataSyncCoordinator.prepareRequiredData(timeout:)`).
    static let timeout: TimeInterval = 20

    private(set) var state: State = .preparing

    private let coordinator: ReferenceDataPreparing
    private let onReady: () -> Void
    let onSignOut: () -> Void

    init(
        coordinator: ReferenceDataPreparing,
        onReady: @escaping () -> Void,
        onSignOut: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.onReady = onReady
        self.onSignOut = onSignOut
    }

    /// Runs once when the screen appears, and again on every "Try again" tap: attempts a sync and
    /// waits for the required datasets to be present, moving on to Home on success.
    func prepare() async {
        state = .preparing
        let ready = await coordinator.prepareRequiredData(timeout: Self.timeout)
        if ready {
            onReady()
        } else {
            state = .failed(isOffline: !coordinator.isDeviceOnline)
        }
    }
}
