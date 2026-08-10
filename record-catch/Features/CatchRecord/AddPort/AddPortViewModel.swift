import Foundation

/// View model for the Add-port screen (type-to-search, save to favourites).
///
/// UI-shaped but backed by stubbed, API-shaped providers (see ADR-0004). On a valid selection it
/// adds the port to the user's favourites, then routes back to the correct select screen.
@MainActor
@Observable
final class AddPortViewModel {

    /// Selected vessel name, shown in the header ("Add port to vessel <VESSEL>").
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// Which select screen to return to after saving (`nil` = first-time entry → departure).
    let returnPhase: SelectPortPhase?

    /// The current search text.
    var query: String = ""
    /// The port name selected from the results list (nil until one is chosen).
    var selectedName: String?
    private(set) var didAttemptSubmit = false
    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    /// Port names available to the search field (loaded from the ports provider).
    private(set) var portNames: [String] = []

    private let router: CatchRecordRouter
    private let portSearch: PortSearchProviding
    private let favouritePorts: FavouritePortsProviding

    init(
        vessel: String,
        referenceNumber: String,
        returnPhase: SelectPortPhase?,
        router: CatchRecordRouter,
        portSearch: PortSearchProviding = StubPortSearchProvider(),
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.returnPhase = returnPhase
        self.router = router
        self.portSearch = portSearch
        self.favouritePorts = favouritePorts
    }

    /// The selected `PortOption`, if the user has chosen one from the list.
    var selectedPort: PortOption? {
        selectedName.map(PortOption.init(name:))
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return AddPortValidation.errorKey(for: selectedPort)
    }

    /// The route to push after a successful save. Pure and independent of async work, so it is
    /// unit-testable directly (first entry and departure both return to departure).
    var completionRoute: CatchRecordRoute {
        let phase = returnPhase ?? .departure
        return .selectPort(phase: phase, vessel: vessel, referenceNumber: referenceNumber)
    }

    /// Loads the searchable port list up front so the field can filter locally. Failures leave the
    /// list empty (the search simply returns no results) rather than blocking the screen.
    func loadPorts() async {
        portNames = ((try? await portSearch.allPorts()) ?? []).map(\.name)
    }

    /// Validates, adds the selected port to favourites, and routes to the correct select screen.
    func submit() async {
        didAttemptSubmit = true
        saveFailed = false
        guard let port = selectedPort else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await favouritePorts.addFavourite(port)
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
