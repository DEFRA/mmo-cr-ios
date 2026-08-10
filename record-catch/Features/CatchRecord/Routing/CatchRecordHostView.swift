import SwiftUI

/// Hosts the single `NavigationStack` for the "Create a catch record" journey, rooted at `Home`.
///
/// Owns the `CatchRecordRouter`, binds it to the stack's `path`, and maps every
/// `CatchRecordRoute` to its screen (see ADR-0003). `HomeView` and the journey screens read the
/// router from the environment rather than receiving it as an explicit dependency at each call
/// site, matching how `AppLanguageStore` is shared today.
struct CatchRecordHostView: View {

    @State private var router: CatchRecordRouter

    /// - Parameter initialRoute: optional route to seed the stack with at launch, used by UI
    ///   tests to jump straight to a screen (see `-uiTestCatchRecordDraft` / `-uiTestCatchRecordNew`).
    init(initialRoute: CatchRecordRoute? = nil) {
        let router = CatchRecordRouter()
        if let initialRoute {
            router.push(initialRoute)
        }
        _router = State(wrappedValue: router)
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
        case .tripStartedToday(let referenceNumber):
            TripStartedTodayView(referenceNumber: referenceNumber, router: router)
        case .tripDate(let phase, let referenceNumber, let departureDate):
            TripDateView(
                phase: phase,
                referenceNumber: referenceNumber,
                departureDate: departureDate,
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
