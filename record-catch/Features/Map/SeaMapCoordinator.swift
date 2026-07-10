import MapKit
import SwiftUI

/// Owns map delegate callbacks, tap-to-select handling, and selection state.
///
/// Selection changes now update only the affected overlay renderer(s) and
/// annotation view(s) directly, instead of calling `setNeedsDisplay()` on
/// every overlay on the map.
final class SeaMapCoordinator: NSObject, MKMapViewDelegate {

    weak var mapView: MKMapView?

    private var selectedSubzone: Binding<String?>
    private var overlays: [SubzoneOverlay] = []

    /// Renderer lookup keyed by sub_code, populated as MapKit requests renderers.
    private var renderersBySubCode: [String: SubzoneOverlayRenderer] = [:]

    /// Annotation view lookup keyed by sub_code, populated as MapKit requests views.
    private var annotationViewsBySubCode: [String: SubzoneAnnotationView] = [:]

    /// The sub_code currently reflected in the renderers/annotation views.
    /// Used to no-op `syncSelection(_:)` when SwiftUI calls `updateUIView`
    /// without the selection actually having changed, and to know which
    /// visuals still need clearing when it has.
    private var lastAppliedSubCode: String?

    init(selectedSubzone: Binding<String?>) {
        self.selectedSubzone = selectedSubzone
        self.lastAppliedSubCode = selectedSubzone.wrappedValue
    }

    func load(overlays: [SubzoneOverlay], annotations: [SubzoneAnnotation], into mapView: MKMapView) {
        self.overlays = overlays
        self.mapView = mapView

        mapView.addOverlays(overlays)
        mapView.addAnnotations(annotations)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let subzoneOverlay = overlay as? SubzoneOverlay else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer = SubzoneOverlayRenderer(overlay: subzoneOverlay)
        renderer.isSelected = subzoneOverlay.subCode == selectedSubzone.wrappedValue
        renderersBySubCode[subzoneOverlay.subCode] = renderer
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let subzoneAnnotation = annotation as? SubzoneAnnotation else {
            return nil
        }

        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: SubzoneAnnotationView.reuseIdentifier
        ) as? SubzoneAnnotationView ?? SubzoneAnnotationView(
            annotation: subzoneAnnotation,
            reuseIdentifier: SubzoneAnnotationView.reuseIdentifier
        )

        view.annotation = subzoneAnnotation

        let isSelected = subzoneAnnotation.subCode == selectedSubzone.wrappedValue
        view.configure(subCode: subzoneAnnotation.subCode, isSelected: isSelected)
        view.isHidden = !LabelVisibility.shouldShowLabels(forLatitudeDelta: mapView.region.span.latitudeDelta)

        annotationViewsBySubCode[subzoneAnnotation.subCode] = view
        return view
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let showLabels = LabelVisibility.shouldShowLabels(forLatitudeDelta: mapView.region.span.latitudeDelta)

        for view in annotationViewsBySubCode.values {
            view.isHidden = !showLabels
        }
    }

    // MARK: - Tap handling

    @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = gesture.view as? MKMapView else { return }

        let tapPoint = gesture.location(in: mapView)
        let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)

        select(SubzoneHitTester.subzoneCode(at: coordinate, in: overlays))
    }

    /// Called from a tap gesture. Writes the new selection to the binding
    /// and updates the affected views. Safe to call from a gesture handler
    /// (not during a SwiftUI view update pass).
    func select(_ subCode: String?) {
        selectedSubzone.wrappedValue = subCode
        applySelection(subCode)
    }

    /// Called from `updateUIView`. Makes the renderers/annotation views
    /// match `subCode` **without** writing back to the `selectedSubzone`
    /// binding — writing to a binding from inside `updateUIView` is what
    /// produces SwiftUI's "Modifying state during view update" warning,
    /// even when the value being written is unchanged.
    func syncSelection(_ subCode: String?) {
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
