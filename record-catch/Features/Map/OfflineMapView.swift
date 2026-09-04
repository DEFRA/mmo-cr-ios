import MapKit
import SwiftUI

/// Reusable, fully offline fisheries map.
///
/// Renders three bundled GeoJSON layers — the main map, subrectangle boundaries/labels, and
/// ports — entirely from local resources, with no Apple Maps tiles and no network requests (see
/// `BlankOfflineTileOverlay`).
///
/// - **Ports are display-only**: they're never selectable and never show a callout — their dot is
///   drawn by `PortsOverlay`/`PortsOverlayRenderer` and their name by a non-interactive
///   `PortLabelAnnotationView` (see those types' doc comments) — the parent never learns about a
///   port tap.
/// - **Subrectangles are selectable**: tapping one highlights it and reports its
///   `SubrectangleProperties` via `selectedSubrectangle`. Tapping somewhere that isn't inside any
///   subrectangle clears the selection.
/// - **The initial camera position is set once**, from `initialCoordinate`/`initialSpan`, in
///   `makeUIView` — never in `updateUIView` — so the caller's subsequent pan/zoom is preserved
///   across SwiftUI view updates and the map is never refit to the GeoJSON extent.
/// - **Zoom is hard-limited** to a fixed *distance* range (see `minZoomDistance`/`maxZoomDistance`)
///   via `MKMapView.CameraZoomRange`, so a pinch/double-tap gesture can never zoom out past a
///   near-global, context-free view or in past a single flat-shaded polygon's fill — both of
///   which would just show a blank, uninformative screen given these are static vector layers,
///   not real imagery. `CameraZoomRange` is enforced by MapKit itself, continuously, for the
///   whole duration of the gesture — not corrected afterwards — so the limit is a genuine hard
///   stop with no overshoot/bounce-back.
/// - **Panning is hard-limited** to roughly 100 miles from the map's *initial* centre (see
///   `MapPanLimit`) via `MKMapView.cameraBoundary` — the same "MapKit enforces it natively,
///   continuously" approach as the zoom limit, so a user can't pan away to an empty, unrelated
///   part of the world and lose all context relative to where the screen opened.
///
/// Usage:
/// ```swift
/// @State private var selectedSubrectangle: SubrectangleProperties?
///
/// OfflineMapView(
///     initialCoordinate: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
///     initialSpan: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0),
///     selectedSubrectangle: $selectedSubrectangle
/// )
/// ```
struct OfflineMapView: UIViewRepresentable {

    /// Hard zoom-in limit, in metres from the camera to the map's centre — shows roughly a 2×2
    /// block of subrectangles on `CatchLocationView`'s 3:4 map (measured empirically; see
    /// `maxZoomDistance`'s doc comment for why this has to be measured against a real view size).
    /// Every layer here is flat-shaded vector geometry with no finer detail to reveal (no imagery,
    /// no street-level content), so zooming in past this just shows an increasingly large blank
    /// fill of whichever single subrectangle/land polygon the user is inside — never useful, and
    /// it makes it easy to lose all on-screen context. Plain hardcoded metres; adjust freely.
    static let minZoomDistance: CLLocationDistance = 115_000

    /// Hard zoom-out limit, in metres from the camera to the map's centre — shows roughly a 4×4
    /// block of subrectangles on `CatchLocationView`'s 3:4 map. Plain hardcoded metres; adjust
    /// freely.
    ///
    /// Must comfortably exceed the distance the *default/initial* framing settles at
    /// (`PortMapCamera.subrectangleGridSpan`, ~3×3) — `cameraZoomRange` clamps **every** region
    /// change, including the very first `setRegion` call in `makeUIView`, so if this limit is
    /// smaller than what the default framing needs, the initial view silently ends up more zoomed
    /// in than intended (this bit us once already: 150,000m here was tighter than the ~174,600m
    /// the 3×3 default needs on this view's aspect ratio, so the app opened showing only ~2
    /// squares wide instead of ~3). `centerCoordinateDistance` is both latitude- and
    /// view-size-dependent (see `docs/design-specs` history for the full explanation), so these
    /// two constants were measured directly against `CatchLocationView`'s real 3:4 frame rather
    /// than computed from the grid cell size in the abstract.
    static let maxZoomDistance: CLLocationDistance = 235_000

    /// The hard zoom limit MapKit applies to the map view — see `minZoomDistance`/
    /// `maxZoomDistance`. Built once, from those two fixed constants, so a failure here can only
    /// ever be a programmer error (`minZoomDistance` set higher than `maxZoomDistance`), not a
    /// runtime condition to handle gracefully.
    static let cameraZoomRange: MKMapView.CameraZoomRange = {
        guard let range = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: minZoomDistance,
            maxCenterCoordinateDistance: maxZoomDistance
        ) else {
            preconditionFailure("minZoomDistance must not exceed maxZoomDistance")
        }
        return range
    }()

    let initialCoordinate: CLLocationCoordinate2D
    let initialSpan: MKCoordinateSpan

    @Binding var selectedSubrectangle: SubrectangleProperties?

    init(
        initialCoordinate: CLLocationCoordinate2D,
        initialSpan: MKCoordinateSpan,
        selectedSubrectangle: Binding<SubrectangleProperties?>
    ) {
        self.initialCoordinate = initialCoordinate
        self.initialSpan = initialSpan
        self._selectedSubrectangle = selectedSubrectangle
    }

    func makeCoordinator() -> OfflineMapCoordinator {
        OfflineMapCoordinator(selectedSubrectangle: $selectedSubrectangle)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // NOTE: plain literals rather than `AppLanguageStore`/`LocalizedText` — this component is
        // deliberately app-agnostic/reusable (see file doc comment); wiring it into the app's
        // custom localisation store is a follow-up if/when this ships beyond internal use.
        map.accessibilityLabel = "Fisheries map"
        map.accessibilityHint = "Tap a subrectangle to select it"

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(OfflineMapCoordinator.handleMapTap(_:))
        )
        tapGesture.cancelsTouchesInView = false
        map.addGestureRecognizer(tapGesture)

        map.showsScale = false
        map.showsTraffic = false
        map.showsBuildings = false
        map.showsUserLocation = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        // Excluding all points-of-interest avoids MapKit's separate POI data/icon fetching —
        // another potential network dependency this offline component doesn't need.
        map.pointOfInterestFilter = .excludingAll

        map.layer.borderColor = MapColorPalette.mapBorder.cgColor
        map.layer.borderWidth = 1.5

        // Hard zoom limit — see `minZoomDistance`/`maxZoomDistance`. Enforced natively by MapKit
        // itself, continuously, for the whole gesture — never overshoots and snaps back.
        map.cameraZoomRange = Self.cameraZoomRange

        // Hard pan limit — see `MapPanLimit`. Same native-enforcement approach as the zoom limit
        // above. `CameraBoundary(coordinateRegion:)` is failable (only for a degenerate region,
        // never expected for a real coordinate here); fail-soft rather than crash, matching this
        // file's existing fail-soft loading philosophy — a missing boundary just means unlimited
        // panning, not a broken map.
        if let boundary = MKMapView.CameraBoundary(
            coordinateRegion: MapPanLimit.boundaryRegion(center: initialCoordinate)
        ) {
            map.cameraBoundary = boundary
        } else {
            OfflineMapLogger.logLoadFailure(layer: "panBoundary", error: OfflineMapDataError.invalidGeoJSON)
        }

        // Entirely offline base layer — see `BlankOfflineTileOverlay`. Added first/lowest so the
        // main map, subrectangle and port layers (added by `loadLayers`) draw on top of it.
        //
        // Level MUST be `.aboveLabels`, not `.aboveRoads`: Apple's own road/imagery content sits
        // below its own label tier (town/city names, etc.), so an `.aboveRoads` overlay — even
        // with `canReplaceMapContent = true` — only ever hides the roads/imagery tier and leaves
        // Apple's inland labels drawing on top of it. `.aboveLabels` is the top-most built-in
        // tier, so our (fully opaque, offline-only) tile overlay replaces that too.
        map.addOverlay(BlankOfflineTileOverlay(), level: .aboveLabels)

        loadLayers(into: map, coordinator: context.coordinator)

        // Initial camera position is applied exactly once, here in `makeUIView`.
        // `updateUIView` never touches the region, so the user's subsequent pan/zoom survives
        // every SwiftUI update, and the map is never refit to the GeoJSON data's extent.
        map.setRegion(MKCoordinateRegion(center: initialCoordinate, span: initialSpan), animated: false)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Uses `syncSelection(_:)`, not `select(_:)` — `select(_:)` writes to the
        // `selectedSubrectangle` binding, and mutating a binding from inside `updateUIView`
        // triggers SwiftUI's "Modifying state during view update" warning even when the value is
        // unchanged. `syncSelection` only touches the renderer/annotation views, and no-ops
        // entirely if the selection already matches what's on screen.
        context.coordinator.syncSelection(selectedSubrectangle)
    }

    /// Loads all three map layers, preferring the precomputed bundled `.plist` resources (see
    /// `PrecomputedMapLoader`) — GeoJSON parsing, coordinate reprojection and sea-overlap
    /// sampling already done once, at build time — and falling back to parsing the raw
    /// `.geojson` resources live (see `loadLayersFromRawGeoJSON`) only if a precomputed resource
    /// is missing. Runs once, in `makeUIView`, off the SwiftUI update cycle. A layer that fails to
    /// load either way is logged and simply omitted — one missing/corrupt bundled resource never
    /// crashes the whole map.
    private func loadLayers(into map: MKMapView, coordinator: OfflineMapCoordinator) {
        do {
            let landOverlays = try PrecomputedMapLoader.loadBundledLand()
            let subrectangleResult = try PrecomputedMapLoader.loadBundledSubrectangles()
            let portMarkers = try PrecomputedMapLoader.loadBundledPorts()

            coordinator.load(
                landOverlays: landOverlays,
                subrectangleOverlays: subrectangleResult.overlays,
                selectableSubrectangleOverlays: subrectangleResult.selectableOverlays,
                subrectangleAnnotations: subrectangleResult.annotations,
                portsOverlay: PortsOverlay(markers: portMarkers),
                portLabelAnnotations: PortLabelAnnotation.annotations(for: portMarkers),
                into: map
            )
            return
        } catch {
            OfflineMapLogger.logLoadFailure(layer: "precomputed", error: error)
        }

        loadLayersFromRawGeoJSON(into: map, coordinator: coordinator)
    }

    /// Fallback path: parses the raw bundled `.geojson` resources live, exactly as before this
    /// component started shipping precomputed data. Kept so the map still works if the
    /// precomputed `.plist` resources are ever missing or out of date (see
    /// `docs/development/offline-map-precomputed-data.md`).
    private func loadLayersFromRawGeoJSON(into map: MKMapView, coordinator: OfflineMapCoordinator) {
        let landOverlays: [MapLandOverlay]
        do {
            landOverlays = try MapLandLoader.loadBundled()
        } catch {
            OfflineMapLogger.logLoadFailure(layer: "map", error: error)
            landOverlays = []
        }

        let subrectangleResult: SubrectangleLoader.Result
        do {
            subrectangleResult = try SubrectangleLoader.loadBundled()
        } catch {
            OfflineMapLogger.logLoadFailure(layer: "subrectangles", error: error)
            subrectangleResult = SubrectangleLoader.Result(overlays: [], annotations: [])
        }

        let portMarkers: [PortMarker]
        do {
            portMarkers = try PortLoader.loadBundled()
        } catch {
            OfflineMapLogger.logLoadFailure(layer: "ports", error: error)
            portMarkers = []
        }

        let selectableOverlays = SubrectangleSeaOverlap.overlappingSea(subrectangleResult.overlays, landOverlays: landOverlays)
        let selectableSubCodes = Set(selectableOverlays.map(\.subCode))

        coordinator.load(
            landOverlays: landOverlays,
            subrectangleOverlays: subrectangleResult.overlays,
            selectableSubrectangleOverlays: selectableOverlays,
            subrectangleAnnotations: subrectangleResult.annotations.filter { selectableSubCodes.contains($0.subCode) },
            portsOverlay: PortsOverlay(markers: portMarkers),
            portLabelAnnotations: PortLabelAnnotation.annotations(for: portMarkers),
            into: map
        )
    }
}
