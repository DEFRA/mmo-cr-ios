import SwiftUI

/// Hosts the single `NavigationStack` for the "Create a catch record" journey, rooted at `Home`.
///
/// Owns the `CatchRecordRouter`, binds it to the stack's `path`, and maps every
/// `CatchRecordRoute` to its screen (see ADR-0003). `HomeView` and the journey screens read the
/// router from the environment rather than receiving it as an explicit dependency at each call
/// site, matching how `AppLanguageStore` is shared today.
struct CatchRecordHostView: View {

    @State private var router: CatchRecordRouter
    /// Shared, journey-scoped favourite ports store so a port added on the Add-port screen is
    /// visible on the select screens (offline-first, local source of truth — see ADR-0004).
    /// A reference type shared across every screen in the stack.
    private let favouritePorts: FavouritePortsProviding
    /// Shared, journey-scoped favourite gears store so a gear added on the measurements screen is
    /// visible on the select screen (offline-first, local source of truth — mirrors ports).
    private let favouriteGears: FavouriteGearProviding

    /// - Parameters:
    ///   - initialRoute: optional route to seed the stack with at launch, used by UI tests to jump
    ///     straight to a screen (see `-uiTestCatchRecord*`).
    ///   - favouritePorts: injectable favourites store; UI tests seed it to exercise the
    ///     has-favourites vs no-favourites branches.
    ///   - favouriteGears: injectable favourite gears store; seeded by UI tests as above.
    init(
        initialRoute: CatchRecordRoute? = nil,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider(),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider()
    ) {
        let router = CatchRecordRouter()
        if let initialRoute {
            router.push(initialRoute)
        }
        _router = State(wrappedValue: router)
        self.favouritePorts = favouritePorts
        self.favouriteGears = favouriteGears
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.setPath($0) })) {
            HomeView()
                .navigationDestination(for: CatchRecordRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
    }

    @ViewBuilder
    private func destination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .draftAction(let row):
            DraftActionView(row: row, router: router)
        case .selectVessel:
            SelectVesselView(router: router)
        case .tripStartedToday(let vessel, let referenceNumber):
            TripStartedTodayView(vessel: vessel, referenceNumber: referenceNumber, router: router, favouritePorts: favouritePorts)
        case .tripDate(let phase, let vessel, let referenceNumber, let departureDate):
            TripDateView(
                phase: phase,
                vessel: vessel,
                referenceNumber: referenceNumber,
                departureDate: departureDate,
                router: router,
                favouritePorts: favouritePorts
            )
        case .addPort(let vessel, let referenceNumber, let returnPhase):
            AddPortView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                returnPhase: returnPhase,
                router: router,
                favouritePorts: favouritePorts
            )
        case .selectPort(let phase, let vessel, let referenceNumber):
            SelectPortView(
                phase: phase,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouritePorts: favouritePorts,
                favouriteGears: favouriteGears
            )
        case .selectGear(let vessel, let referenceNumber):
            SelectGearView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteGears: favouriteGears
            )
        case .addGear(let vessel, let referenceNumber):
            AddGearView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router
            )
        case .gearMeasurements(let gear, let vessel, let referenceNumber):
            GearMeasurementsView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteGears: favouriteGears
            )
        case .catchLocation(let gear, let vessel, let referenceNumber):
            CatchLocationView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router
            )
        case .placeholderNextStep:
            PlaceholderNextStepView()
        }
    }
}

#Preview("English") {
    CatchRecordHostView()
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    CatchRecordHostView()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    CatchRecordHostView()
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
