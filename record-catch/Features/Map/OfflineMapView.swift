import MapKit
import SwiftUI

/// Reusable, fully offline fisheries map.
///
/// Renders three bundled GeoJSON layers — the main map, subrectangle boundaries/labels, and
/// ports — entirely from local resources, with no Apple Maps tiles and no network requests (see
/// `BlankOfflineTileOverlay`).
///
/// - **Ports are display-only**: they're never selectable and never show a callout (see
///   `PortsOverlay`/`PortsOverlayRenderer`) — the parent never learns about a port tap.
/// - **Subrectangles are selectable**: tapping one highlights it and reports its
///   `SubrectangleProperties` via `selectedSubrectangle`. Tapping somewhere that isn't inside any
///   subrectangle clears the selection.
/// - **The initial camera position is set once**, from `initialCoordinate`/`initialSpan`, in
///   `makeUIView` — never in `updateUIView` — so the caller's subsequent pan/zoom is preserved
///   across SwiftUI view updates and the map is never refit to the GeoJSON extent.
/// - **Zoom is hard-limited** to a fixed distance range (see `maxZoomOutDistance`/
///   `maxZoomInDistance`) so a pinch/double-tap gesture can never zoom out past a near-global,
///   context-free view or in past a single flat-shaded polygon's fill — both of which would just
///   show a blank, uninformative screen given these are static vector layers, not real imagery.
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

    /// Hard zoom-out limit. The offline layers are three fixed, bundled GeoJSON datasets — beyond
    /// this distance there's nothing more to see: just a shrinking sliver of the UK's coastline
    /// adrift in a mostly blank white "sea" (see `BlankOfflineTileOverlay`), with no real-world
    /// basemap context to make that useful. Comfortably covers the whole-UK default view (see
    /// `CatchLocationView`'s ~12°×8° default span) with room to spare, while still stopping a pinch
    /// gesture well short of a near-global view.
    private static let maxZoomOutDistance: CLLocationDistance = 200_000

    /// Hard zoom-in limit. Every layer here is flat-shaded vector geometry with no finer detail to
    /// reveal (no imagery, no street-level content) — zooming in past this just shows an
    /// increasingly large blank fill of whichever single subrectangle/land polygon the user is
    /// inside, which is never useful and makes it easy to lose all on-screen context.
    private static let maxZoomInDistance: CLLocationDistance = 60_000

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

        // Hard zoom limits (see the doc comments on `maxZoomOutDistance`/`maxZoomInDistance`) — set
        // once, here, alongside the initial camera position; unlike the region itself this never
        // needs to change on subsequent SwiftUI updates, so `updateUIView` never touches it either.
        // The initialiser is failable only if `min > max`, which these fixed constants never are,
        // but a `nil` result is handled instead of force-unwrapped (see swift-swiftui instructions).
        if let zoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: Self.maxZoomInDistance,
            maxCenterCoordinateDistance: Self.maxZoomOutDistance
        ) {
            map.setCameraZoomRange(zoomRange, animated: false)
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
            into: map
        )
    }
}
