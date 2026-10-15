import MapKit
import SwiftUI

/// Owns map delegate callbacks, tap-to-select handling, and subrectangle selection state for
/// `OfflineMapView`.
///
/// Selection changes update only the affected overlay renderer(s) and annotation view(s)
/// directly, instead of calling `setNeedsDisplay()` on every overlay on the map.
final class OfflineMapCoordinator: NSObject, MKMapViewDelegate {

    weak var mapView: MKMapView?

    private var selectedSubrectangle: Binding<SubrectangleProperties?>
    private var subrectangleOverlays: [SubrectangleOverlay] = []

    /// Renderer lookup keyed by sub_code, populated as MapKit requests renderers.
    private var renderersBySubCode: [String: SubrectangleOverlayRenderer] = [:]

    /// Annotation view lookup keyed by sub_code, populated as MapKit requests views.
    private var annotationViewsBySubCode: [String: SubrectangleAnnotationView] = [:]

    /// The sub_code currently reflected in the renderers/annotation views.
    /// Used to no-op `syncSelection(_:)` when SwiftUI calls `updateUIView` without the selection
    /// actually having changed, and to know which visuals still need clearing when it has.
    private var lastAppliedSubCode: String?

    init(selectedSubrectangle: Binding<SubrectangleProperties?>) {
        self.selectedSubrectangle = selectedSubrectangle
        self.lastAppliedSubCode = selectedSubrectangle.wrappedValue?.subCode
    }

    /// Adds every layer to `mapView` in the required visual order: main map, then subrectangle
    /// boundaries, then subrectangle labels, then ports on top.
    ///
    /// The offline base tile overlay is added separately by `OfflineMapView` (it has no
    /// per-feature data for this type to own) — always before this call, so it sits below
    /// everything added here.
    ///
    /// Every overlay here uses `.aboveLabels`, matching the base tile overlay (see
    /// `OfflineMapView.makeUIView`): overlays at the same level stack in insertion order, so land
    /// → subrectangles → ports draws in exactly that order, all above Apple's own label tier.
    ///
    /// Every subrectangle's grid boundary is still drawn (`subrectangleOverlays` is added
    /// unfiltered), but only `selectableSubrectangleOverlays` — those that overlap the sea (see
    /// `SubrectangleSeaOverlap`) — participate in tap hit-testing, and only their matching
    /// `subrectangleAnnotations` should have been supplied: a purely inland subrectangle has no
    /// real fishing area, so it's never labelled or selectable. Deciding *which* subrectangles
    /// overlap the sea is the caller's job (`OfflineMapView`) — normally read straight from the
    /// bundled precomputed data (see `PrecomputedMapLoader`), so this method itself never repeats
    /// that (comparatively expensive) point-sampling work.
    ///
    /// `portLabelAnnotations` defaults to empty so existing call sites (and tests) that don't care
    /// about port names keep compiling unchanged; `OfflineMapView` always supplies the full set
    /// derived from its loaded `PortMarker`s.
    func load(
        landOverlays: [MapLandOverlay],
        subrectangleOverlays: [SubrectangleOverlay],
        selectableSubrectangleOverlays: [SubrectangleOverlay],
        subrectangleAnnotations: [SubrectangleAnnotation],
        portsOverlay: PortsOverlay,
        portLabelAnnotations: [PortLabelAnnotation] = [],
        into mapView: MKMapView
    ) {
        // Only selectable overlays participate in tap hit-testing (see `handleMapTap`) — a purely
        // inland subrectangle can never be selected, regardless of where within it is tapped.
        self.subrectangleOverlays = selectableSubrectangleOverlays
        self.mapView = mapView

        mapView.addOverlays(landOverlays, level: .aboveLabels)
        mapView.addOverlays(subrectangleOverlays, level: .aboveLabels)
        mapView.addAnnotations(subrectangleAnnotations)
        mapView.addOverlay(portsOverlay, level: .aboveLabels)
        mapView.addAnnotations(portLabelAnnotations)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }

        if let landOverlay = overlay as? MapLandOverlay {
            return MapLandOverlayRenderer(overlay: landOverlay)
        }

        if let subrectangleOverlay = overlay as? SubrectangleOverlay {
            let renderer = SubrectangleOverlayRenderer(overlay: subrectangleOverlay)
            renderer.isSelected = subrectangleOverlay.subCode == selectedSubrectangle.wrappedValue?.subCode
            renderersBySubCode[subrectangleOverlay.subCode] = renderer
            return renderer
        }

        if let portsOverlay = overlay as? PortsOverlay {
            return PortsOverlayRenderer(overlay: portsOverlay)
        }

        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let subrectangleAnnotation = annotation as? SubrectangleAnnotation {
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: SubrectangleAnnotationView.reuseIdentifier
            ) as? SubrectangleAnnotationView ?? SubrectangleAnnotationView(
                annotation: subrectangleAnnotation,
                reuseIdentifier: SubrectangleAnnotationView.reuseIdentifier
            )

            view.annotation = subrectangleAnnotation

            let isSelected = subrectangleAnnotation.subCode == selectedSubrectangle.wrappedValue?.subCode
            view.configure(subCode: subrectangleAnnotation.subCode, isSelected: isSelected)
            view.isHidden = !LabelVisibility.shouldShowLabels(forLatitudeDelta: mapView.region.span.latitudeDelta)

            annotationViewsBySubCode[subrectangleAnnotation.subCode] = view
            return view
        }

        // Ports' marker dots are rendered via `PortsOverlay`/`PortsOverlayRenderer`, never as
        // annotations — only their name labels are annotation views, and those are structurally
        // prevented from being selectable/callout-able (see `PortLabelAnnotationView`).
        if let portLabelAnnotation = annotation as? PortLabelAnnotation {
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PortLabelAnnotationView.reuseIdentifier
            ) as? PortLabelAnnotationView ?? PortLabelAnnotationView(
                annotation: portLabelAnnotation,
                reuseIdentifier: PortLabelAnnotationView.reuseIdentifier
            )

            view.annotation = portLabelAnnotation
            view.configure(name: portLabelAnnotation.name)
            // Deliberately does NOT set `isHidden` from `LabelVisibility` — port name visibility
            // is left entirely to MapKit's own collision handling (`collisionMode`/
            // `displayPriority` — see `PortLabelAnnotationView`). Unlike subrectangle code labels
            // (which must always render regardless of overlap, see `SubrectangleAnnotationView`),
            // port names are allowed to be hidden by a collision at any zoom level within this
            // map's range, so there is no separate zoom-driven rule to apply here. Touching
            // `isHidden` for any other reason would fight MapKit's own decision the next time it
            // re-evaluates collisions.
            return view
        }

        return nil
    }

    /// Applies `LabelVisibility`'s zoom-based show/hide decision to every subrectangle code label.
    ///
    /// Only subrectangle labels are touched here — port name labels are deliberately left alone
    /// (see `viewFor annotation:`) because their visibility is owned entirely by MapKit's own
    /// collision handling, not by zoom. Subrectangle labels use `collisionMode = .none` (they must
    /// always render), so there's no competing decision to avoid overriding, and this can simply
    /// reassert `isHidden` unconditionally on every region change.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
        let showLabels = LabelVisibility.shouldShowLabels(forLatitudeDelta: mapView.region.span.latitudeDelta)

        for view in annotationViewsBySubCode.values {
            view.isHidden = !showLabels
        }

        // Zoom is hard-limited by `OfflineMapView.cameraZoomRange`, set on `mapView` once in
        // `makeUIView` — MapKit enforces that natively and continuously, so no correction is
        // needed here.
    }

    // MARK: - Tap handling

    @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = gesture.view as? MKMapView else { return }

        let tapPoint = gesture.location(in: mapView)
        let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)

        // Only subrectangle overlays participate in hit testing — the main map layer and ports
        // are never selectable, regardless of where the user taps. A tap that lands outside every
        // subrectangle (e.g. on land, or open water beyond the grid) clears the selection.
        select(SubrectangleHitTester.subrectangle(at: coordinate, in: subrectangleOverlays)?.properties)
    }

    /// Called from a tap gesture. Writes the new selection to the binding and updates the
    /// affected views. Safe to call from a gesture handler (not during a SwiftUI view update pass).
    func select(_ properties: SubrectangleProperties?) {
        selectedSubrectangle.wrappedValue = properties
        applySelection(properties?.subCode)
    }

    /// Called from `updateUIView`. Makes the renderers/annotation views match `properties`
    /// **without** writing back to the `selectedSubrectangle` binding — writing to a binding from
    /// inside `updateUIView` is what produces SwiftUI's "Modifying state during view update"
    /// warning, even when the value being written is unchanged.
    func syncSelection(_ properties: SubrectangleProperties?) {
        let subCode = properties?.subCode
        guard subCode != lastAppliedSubCode else { return }
        applySelection(subCode)
    }

    private func applySelection(_ subCode: String?) {
        let changedSubCodes = Set([lastAppliedSubCode, subCode].compactMap { $0 })

        for changedSubCode in changedSubCodes {
            let isSelected = changedSubCode == subCode

            renderersBySubCode[changedSubCode]?.isSelected = isSelected

            if let view = annotationViewsBySubCode[changedSubCode] {
                view.configure(subCode: changedSubCode, isSelected: isSelected)
            }
        }

        lastAppliedSubCode = subCode
    }
}
