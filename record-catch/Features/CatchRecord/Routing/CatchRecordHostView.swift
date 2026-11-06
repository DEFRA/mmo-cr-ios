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
    @Environment(\.scenePhase) private var scenePhase

    @State private var router: CatchRecordRouter
    /// Injectable override for the journey-scoped favourite ports store (see ADR-0023: favourites
    /// are per-user, not per-trip). `nil` by default, in which case a
    /// `SwiftDataFavouritePortsProvider` bound to the environment's `modelContext` is used —
    /// deferred to a computed property since `modelContext` is not available until the view
    /// resolves its environment (i.e. not yet at `init`), mirroring `draftStore` below. UI tests
    /// inject a seeded `StubFavouritePortsProvider` instead, to exercise the
    /// has-favourites/no-favourites branches deterministically.
    private let injectedFavouritePorts: FavouritePortsProviding?
    /// Injectable override for the journey-scoped favourite gears store — see
    /// `injectedFavouritePorts` above (mirrors it exactly).
    private let injectedFavouriteGears: FavouriteGearProviding?
    /// Injectable override for the journey-scoped favourite species store — see
    /// `injectedFavouritePorts` above (mirrors it exactly).
    private let injectedFavouriteSpecies: FavouriteSpeciesProviding?
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
    /// Injectable override for `HomeView`'s records source. Defaults to `nil`, in which case the
    /// production `MergingRecordsRepository(draftStore:)` is used (local Unsent drafts merged with
    /// stubbed server records — see ADR-0015). UI tests use this to seed a deterministic row count
    /// (e.g. `-uiTestHomePaged`'s 6 rows) without depending on `draftStore` state.
    private let injectedRecordsProvider: RecordsProviding?

    private var draftStore: CatchRecordDraftStoring {
        injectedDraftStore ?? SwiftDataCatchRecordDraftStore(modelContext: modelContext)
    }

    /// The favourite ports store for this journey - the injected override (tests/previews), or a
    /// `SwiftDataFavouritePortsProvider` bound to the environment's `modelContext` in production
    /// (see `injectedFavouritePorts`, ADR-0023). Recomputed, not cached: every instance wraps the
    /// same `modelContext`, so reads/writes from any screen in the stack stay consistent without
    /// needing a single shared object identity (unlike the old in-memory `StubFavouriteGearProvider`).
    private var favouritePorts: FavouritePortsProviding {
        injectedFavouritePorts ?? SwiftDataFavouritePortsProvider(modelContext: modelContext)
    }
    /// The favourite gears store for this journey — see `favouritePorts` above (mirrors it exactly).
    private var favouriteGears: FavouriteGearProviding {
        injectedFavouriteGears ?? SwiftDataFavouriteGearProvider(modelContext: modelContext)
    }
    /// The favourite species store for this journey — see `favouritePorts` above (mirrors it
    /// exactly).
    private var favouriteSpecies: FavouriteSpeciesProviding {
        injectedFavouriteSpecies ?? SwiftDataFavouriteSpeciesProvider(modelContext: modelContext)
    }

    /// Debounced autosave for in-progress, not-yet-routed edits (see `DraftAutosaver`,
    /// BR-SUB-008/AC14). Created once, lazily, the first time it is needed - `modelContext` (via
    /// `draftStore`) is not available until the view resolves its environment, i.e. not yet at
    /// `init` — and held in `@State` so the same instance (and its debounce timer) persists across
    /// view updates for the lifetime of this journey.
    @State private var autosaver: DraftAutosaver?

    private func autosaverInstance() -> DraftAutosaver {
        if let autosaver { return autosaver }
        let created = DraftAutosaver(store: draftStore)
        autosaver = created
        return created
    }

    /// - Parameters:
    ///   - initialRoute: optional route to seed the stack with at launch, used by UI tests to jump
    ///     straight to a screen (see `-uiTestCatchRecord*`).
    ///   - favouritePorts: injectable override for the per-user favourite ports store. Defaults to
    ///     `nil`, in which case a `SwiftDataFavouritePortsProvider` is used (see ADR-0023). UI tests
    ///     pass a seeded `StubFavouritePortsProvider` to exercise the has-favourites vs
    ///     no-favourites branches deterministically.
    ///   - favouriteGears: injectable override for the per-user favourite gears store; see
    ///     `favouritePorts` above.
    ///   - favouriteSpecies: injectable override for the per-user favourite species store; see
    ///     `favouritePorts` above.
    ///   - draft: injectable journey draft; UI tests can seed it to jump into a mid-journey state.
    ///   - draftStore: injectable on-device draft persistence; UI tests/previews can supply an
    ///     `InMemoryCatchRecordDraftStore` instead of a real `ModelContainer`.
    ///   - recordsProvider: injectable override for `HomeView`'s records source; UI tests use this
    ///     to seed a deterministic row count (e.g. for pagination) without depending on
    ///     `draftStore` state.
    init(
        initialRoute: CatchRecordRoute? = nil,
        favouritePorts: FavouritePortsProviding? = nil,
        favouriteGears: FavouriteGearProviding? = nil,
        favouriteSpecies: FavouriteSpeciesProviding? = nil,
        draft: CatchRecordDraft? = nil,
        draftStore: CatchRecordDraftStoring? = nil,
        recordsProvider: RecordsProviding? = nil
    ) {
        let router = CatchRecordRouter()
        if let initialRoute {
            router.push(initialRoute)
        }
        _router = State(wrappedValue: router)
        injectedFavouritePorts = favouritePorts
        injectedFavouriteGears = favouriteGears
        injectedFavouriteSpecies = favouriteSpecies
        _draft = State(wrappedValue: draft ?? CatchRecordDraft())
        injectedDraftStore = draftStore
        injectedRecordsProvider = recordsProvider
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.setPath($0) })) {
            HomeView(recordsProvider: injectedRecordsProvider ?? MergingRecordsRepository(draftStore: draftStore))
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
        // Home row. `CatchRecordRouter.shouldPersistDraft` gates this on the vessel step having
        // actually been **committed** (not merely shown) and on not having just reached
        // `.submissionSuccess` — see that function's doc comment, and ADR-0014 §4 (amended).
        .onChange(of: router.path) { _, newPath in
            guard CatchRecordRouter.shouldPersistDraft(path: newPath, vessel: draft.vessel) else { return }
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
        // Debounced autosave of in-progress edits on the *current* screen — i.e. before the user
        // reaches the next route boundary above (see `DraftAutosaver`, BR-SUB-008/AC14). Reading
        // `draft.payload` (rather than each individual property) makes the `@Observable` draft's
        // entire persisted surface the dependency, so this fires on every field change without
        // per-property wiring. Gated by the same `shouldPersistDraft` rule as the route-change save
        // above, so an abandoned journey (still on `.selectVessel`, or just past
        // `.submissionSuccess`) never creates or resurrects a row.
        .onChange(of: draft.payload) { _, _ in
            guard CatchRecordRouter.shouldPersistDraft(path: router.path, vessel: draft.vessel) else { return }
            autosaverInstance().schedule(draft)
        }
        // Flushes any pending debounced save immediately when the app leaves the foreground, so an
        // edit mid-debounce is not lost if the process is suspended or terminated before the
        // debounce interval elapses (BR-SUB-008/AC15 — "no saved data is lost").
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active,
                  CatchRecordRouter.shouldPersistDraft(path: router.path, vessel: draft.vessel) else { return }
            autosaverInstance().flush(draft)
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
        case .catchLocation, .catchLocationNearestAreas, .catchLocationManualEntry,
             .recordSpeciesWeights, .addSpecies, .removeSpecies:
            speciesDestination(for: route)
        case .landingStorage, .landingStorageSpecies, .checkYourAnswers,
             .submissionSuccess, .submissionSaved:
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
                draft: draft
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
        case .catchLocationNearestAreas(let gear, let vessel, let referenceNumber):
            CatchLocationNearestAreasView(
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
            CheckYourAnswersView(referenceNumber: referenceNumber, router: router, draft: draft, draftStore: draftStore)
        case .submissionSuccess(let referenceNumber):
            SubmissionSuccessView(referenceNumber: referenceNumber, router: router)
        case .submissionSaved(let referenceNumber):
            SubmissionSavedView(referenceNumber: referenceNumber, router: router)
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
