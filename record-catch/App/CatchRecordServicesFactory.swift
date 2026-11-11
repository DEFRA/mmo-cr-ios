//
//  CatchRecordServicesFactory.swift
//  record-catch
//
//  Composition-root wiring for the Catch Recording Service connector (ADR-0025). **Not yet
//  plugged into any screen or view model** — building `CatchRecordServicesFactory.Services` has no
//  visible effect on the app today; this exists purely so the connector has a real construction
//  path ready for whichever feature wires it in next.
//

import Foundation

/// Bundles the three Catch Recording Service connector protocols this app depends on, so a single
/// call site constructs all three consistently (same base URL, same token provider, same HTTP
/// client) rather than three independent call sites drifting apart.
struct CatchRecordServices {
    let catchRecords: any CatchRecordServicing
    let vesselFavourites: any VesselFavouritesServicing
    let platform: any CatchRecordPlatformServicing
}

enum CatchRecordServicesFactory {
    /// The `MMOCRAppConfig` key the Catch Recording Service's base URL is read from — deliberately
    /// distinct from `API_BASE_URL` (the reference-data service's own address). See
    /// `Config/app-config.schema.json`/ADR-0025.
    private static let baseURLConfigKey = "CATCH_RECORD_API_BASE_URL"

    /// Builds the connector's three services.
    ///
    /// - Parameter authenticator: Resolves the app's single shared `Authenticating` instance (see
    ///   `RootSessionCoordinator.sharedAuthenticator`) — bearer tokens are resolved from the *same*
    ///   signed-in MSAL session every other authenticated request in the app uses, never a second,
    ///   independent sign-in state.
    /// - Returns: Real, network-backed services when `CATCH_RECORD_API_BASE_URL` is configured and
    ///   this is not a `-uiTest*` launch; `Stub*` services under `-uiTest*` (so XCUITest never
    ///   depends on live network access — mirrors `ReferenceDataSyncCoordinator.make`); `Failing*`
    ///   services — which throw `APIError.invalidConfiguration` from every method, a safe, visible
    ///   degradation rather than a crash — whenever the base URL is not yet configured for this
    ///   stage (see ADR-0025 "Placeholder base URL").
    @MainActor
    static func make(authenticator: @escaping @MainActor () -> any Authenticating) -> CatchRecordServices {
        guard !LaunchArguments.current.isUITesting else {
            return CatchRecordServices(
                catchRecords: StubCatchRecordService(),
                vesselFavourites: StubVesselFavouritesService(),
                platform: StubCatchRecordPlatformService()
            )
        }

        guard let configuration = try? APIConfiguration(key: baseURLConfigKey) else {
            return CatchRecordServices(
                catchRecords: FailingCatchRecordService(),
                vesselFavourites: FailingVesselFavouritesService(),
                platform: FailingCatchRecordPlatformService()
            )
        }

        let httpClient = URLSessionHTTPClient()
        let tokenProvider = MSALAccessTokenProvider(authenticator: authenticator)
        return CatchRecordServices(
            catchRecords: CatchRecordService(httpClient: httpClient, configuration: configuration, tokenProvider: tokenProvider),
            vesselFavourites: VesselFavouritesService(httpClient: httpClient, configuration: configuration, tokenProvider: tokenProvider),
            platform: CatchRecordPlatformService(httpClient: httpClient, configuration: configuration, tokenProvider: tokenProvider)
        )
    }
}
