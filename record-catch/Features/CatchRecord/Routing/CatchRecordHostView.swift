import SwiftUI
import SwiftData

/// Hosts the single `NavigationStack` for the "Create a catch record" journey, rooted at `Home`.
///
/// Owns the `CatchRecordRouter`, binds it to the stack's `path`, and maps every
/// `CatchRecordRoute` to its screen (see ADR-0003). `HomeView` and the journey screens read the
/// router from the environment rather than receiving it as an explicit dependency at each call
/// site, matching how `AppLanguageStore` is shared today.
@MainActor
struct CatchRecordHostView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var router: CatchRecordRouter
    /// Shared, journey-scoped favourite ports store so a port added on the Add-port screen is
    /// visible on the select screens (offline-first, local source of truth — see ADR-0004).
    /// A reference type shared across every screen in the stack.
    @State private var favouritePorts: FavouritePortsProviding
    /// Shared, journey-scoped favourite gears store so a gear added on the measurements screen is
    /// visible on the select screen (offline-first, local source of truth — mirrors ports).
    @State private var favouriteGears: FavouriteGearProviding
    /// Shared, journey-scoped favourite species store so a species added on the Add-species screen,
    /// and weights recorded on the weights screen, are visible on the summary screen (offline-first,
    /// local source of truth — mirrors gears).
    @State private var favouriteSpecies: FavouriteSpeciesProviding
    /// Shared, journey-scoped draft accumulating the in-progress catch record (vessel, dates,
    /// ports, gear and species) so it is available to every screen in the stack without re-deriving
    /// it from route payloads. Offline-first, local source of truth — persisted on-device after
    /// every "Save and continue" via `draftStore` (see ADR-0014, `CatchRecordDraft`).
    @State private var draft: CatchRecordDraft
    /// Injectable on-device draft persistence (see ADR-0014). Defaults to `nil`, in which case a
    /// `SwiftDataCatchRecordDraftStore` bound to the environment's `modelContext` is used — deferred
    /// to a computed property since `modelContext` is not available until the view resolves its
    /// environment (i.e. not yet at `init`).
    private let injectedDraftStore: CatchRecordDraftStoring?

    private var draftStore: CatchRecordDraftStoring {
        injectedDraftStore ?? SwiftDataCatchRecordDraftStore(modelContext: modelContext)
    }

    /// - Parameters:
    ///   - initialRoute: optional route to seed the stack with at launch, used by UI tests to jump
    ///     straight to a screen (see `-uiTestCatchRecord*`).
    ///   - favouritePorts: injectable favourites store; UI tests seed it to exercise the
    ///     has-favourites vs no-favourites branches.
    ///   - favouriteGears: injectable favourite gears store; seeded by UI tests as above.
    ///   - favouriteSpecies: injectable favourite species store; seeded by UI tests as above.
    ///   - draft: injectable journey draft; UI tests can seed it to jump into a mid-journey state.
    ///   - draftStore: injectable on-device draft persistence; UI tests/previews can supply an
    ///     `InMemoryCatchRecordDraftStore` instead of a real `ModelContainer`.
    init(
        initialRoute: CatchRecordRoute? = nil,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider(),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft? = nil,
        draftStore: CatchRecordDraftStoring? = nil
    ) {
        let router = CatchRecordRouter()
        if let initialRoute {
            router.push(initialRoute)
        }
        _router = State(wrappedValue: router)
        _favouritePorts = State(wrappedValue: favouritePorts)
        _favouriteGears = State(wrappedValue: favouriteGears)
        _favouriteSpecies = State(wrappedValue: favouriteSpecies)
        _draft = State(wrappedValue: draft ?? CatchRecordDraft())
        injectedDraftStore = draftStore
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.setPath($0) })) {
            HomeView(recordsProvider: MergingRecordsRepository(draftStore: draftStore))
                .navigationDestination(for: CatchRecordRoute.self) { route in
                    // Single DRY call site (see ADR-0006 §3): hides the root tab bar for every
                    // pushed journey screen, current and future, without touching each of the
                    // 20+ individual destination views. `HomeView` (the un-pushed stack root)
                    // is unaffected, so the tab bar stays visible there.
                    destination(for: route)
                        .toolbar(.hidden, for: .tabBar)
                }
        }
        .environment(router)
        .environment(\.headerNavigator, router)
        .environment(draft)
        // Persists the draft after every "Save and continue" (any route push — see ADR-0014
        // decision #5), so a journey survives app termination and can be resumed as an Unsent
        // Home row. Skips persisting until at least one value has been captured (`draft.vessel`),
        // so a journey abandoned before the very first screen never creates an empty row.
        .onChange(of: router.path) { _, newPath in
            guard !newPath.isEmpty, draft.vessel != nil else { return }
            // Reaching Check your answers is the last section boundary before submission, and is
            // reachable from several places (the landing-storage "No" answer, the
            // landing-storage-species screen, and every "Change" link) — a single, DRY hook here
            // covers all of them, rather than duplicating `draft.advance(to:)` at each call site
            // (see `CatchRecordCheckpoint`, ADR-0014 decision #5, amended).
            if case .checkYourAnswers = newPath.last {
                draft.advance(to: .checkYourAnswers)
            }
            Task { try? await draftStore.save(draft) }
        }
    }

    /// Dispatches to the four journey-section helpers below, each covering a contiguous run of
    /// `CatchRecordRoute` cases. Split out of a single 21-case switch (see ADR-0003) purely to
    /// keep cyclomatic complexity low per function (`cyclomatic_complexity`, `.swiftlint.yml`) —
    /// the routing behaviour is unchanged, just grouped by journey section for readability.
    @ViewBuilder
    private func destination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .draftAction, .selectVessel, .tripStartedToday, .tripDate, .submissionNudge:
            vesselAndTripDestination(for: route)
        case .addPort, .confirmSamePort, .selectPort, .selectGear, .addGear, .gearMeasurements:
            portAndGearDestination(for: route)
        case .catchLocation, .catchLocationManualEntry, .recordSpeciesWeights, .addSpecies, .removeSpecies:
            speciesDestination(for: route)
        case .landingStorage, .landingStorageSpecies, .checkYourAnswers, .submissionConfirmation, .submissionSuccess:
            landingAndSubmissionDestination(for: route)
        }
    }

    /// Draft resumption through to the trip-date/submission-nudge screens (start of the journey).
    @ViewBuilder
    private func vesselAndTripDestination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .draftAction(let row):
            DraftActionView(
                row: row,
                router: router,
                draft: draft,
                draftStore: draftStore,
                favouritePorts: favouritePorts,
                favouriteGears: favouriteGears
            )
        case .selectVessel:
            SelectVesselView(router: router, draft: draft)
        case .tripStartedToday(let vessel, let referenceNumber):
            TripStartedTodayView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouritePorts: favouritePorts,
                draft: draft
            )
        case .tripDate(let phase, let vessel, let referenceNumber, let departureDate):
            TripDateView(
                phase: phase,
                vessel: vessel,
                referenceNumber: referenceNumber,
                departureDate: departureDate,
                router: router,
                favouritePorts: favouritePorts,
                draft: draft
            )
        case .submissionNudge(let daysLate, let vessel, let referenceNumber):
            SubmissionNudgeView(
                daysLate: daysLate,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouritePorts: favouritePorts
            )
        default:
            fatalError("vesselAndTripDestination received an unhandled route: \(route)")
        }
    }

    /// Port selection/confirmation through to gear selection and measurements.
    @ViewBuilder
    private func portAndGearDestination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .addPort(let vessel, let referenceNumber, let returnPhase):
            AddPortView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                returnPhase: returnPhase,
                router: router,
                favouritePorts: favouritePorts
            )
        case .confirmSamePort(let vessel, let referenceNumber, let port):
            ConfirmSamePortView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                port: port,
                router: router,
                favouriteGears: favouriteGears,
                draft: draft
            )
        case .selectPort(let phase, let vessel, let referenceNumber):
            SelectPortView(
                phase: phase,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouritePorts: favouritePorts,
                favouriteGears: favouriteGears,
                draft: draft
            )
        case .selectGear(let vessel, let referenceNumber):
            SelectGearView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteGears: favouriteGears,
                draft: draft
            )
        case .addGear(let vessel, let referenceNumber):
            AddGearView(
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteGears: favouriteGears
            )
        case .gearMeasurements(let gear, let vessel, let referenceNumber):
            GearMeasurementsView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteGears: favouriteGears,
                draft: draft
            )
        default:
            fatalError("portAndGearDestination received an unhandled route: \(route)")
        }
    }

    /// Statistical-area capture through to per-gear species weights and removal.
    @ViewBuilder
    private func speciesDestination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .catchLocation(let gear, let vessel, let referenceNumber):
            CatchLocationView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteSpecies: favouriteSpecies,
                draft: draft
            )
        case .catchLocationManualEntry(let gear, let vessel, let referenceNumber):
            CatchLocationManualEntryView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteSpecies: favouriteSpecies,
                draft: draft
            )
        case .recordSpeciesWeights(let gear, let vessel, let referenceNumber):
            RecordSpeciesWeightsView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                favouriteSpecies: favouriteSpecies,
                draft: draft
            )
        case .addSpecies(let gear, let vessel, let referenceNumber, let returnPhase, let context):
            AddSpeciesView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                returnPhase: returnPhase,
                context: context,
                router: router,
                favouriteSpecies: favouriteSpecies
            )
        case .removeSpecies(let gear, let vessel, let referenceNumber):
            RemoveSpeciesView(
                gear: gear,
                vessel: vessel,
                referenceNumber: referenceNumber,
                router: router,
                draft: draft
            )
        default:
            fatalError("speciesDestination received an unhandled route: \(route)")
        }
    }

    /// Landing/storage questions through to final submission and success.
    @ViewBuilder
    private func landingAndSubmissionDestination(for route: CatchRecordRoute) -> some View {
        switch route {
        case .landingStorage(let referenceNumber):
            LandingStorageView(referenceNumber: referenceNumber, router: router, draft: draft)
        case .landingStorageSpecies(let referenceNumber):
            LandingStorageSpeciesView(
                referenceNumber: referenceNumber,
                router: router,
                favouriteSpecies: favouriteSpecies,
                draft: draft
            )
        case .checkYourAnswers(let referenceNumber):
            CheckYourAnswersView(referenceNumber: referenceNumber, router: router, draft: draft)
        case .submissionConfirmation(let referenceNumber):
            SubmissionConfirmationView(
                referenceNumber: referenceNumber,
                router: router,
                draft: draft,
                draftStore: draftStore
            )
        case .submissionSuccess(let referenceNumber):
            SubmissionSuccessView(referenceNumber: referenceNumber, router: router)
        default:
            fatalError("landingAndSubmissionDestination received an unhandled route: \(route)")
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
