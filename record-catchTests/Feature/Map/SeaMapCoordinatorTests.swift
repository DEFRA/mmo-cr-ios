import XCTest
import MapKit
import SwiftUI
@testable import record_catch

final class SeaMapCoordinatorTests: XCTestCase {

    private func makeRectangleOverlay(
        subCode: String,
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) -> SubzoneOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        return SubzoneOverlay(multiPolygon: MKMultiPolygon([polygon]), subCode: subCode)
    }

    private func makeBinding(initial: String?) -> (Binding<String?>, () -> String?) {
        var storedValue = initial
        let binding = Binding<String?>(
            get: { storedValue },
            set: { storedValue = $0 }
        )
        return (binding, { storedValue })
    }

    func testSelectUpdatesBindingAndOnlyAffectedRenderers() {
        let (binding, currentValue) = makeBinding(initial: nil)
        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let zoneB = makeRectangleOverlay(subCode: "B1", minLat: 55.0, maxLat: 56.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA, zoneB], annotations: [], into: mapView)

        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubzoneOverlayRenderer
        let rendererB = coordinator.mapView(mapView, rendererFor: zoneB) as? SubzoneOverlayRenderer

        XCTAssertEqual(rendererA?.isSelected, false)
        XCTAssertEqual(rendererB?.isSelected, false)

        coordinator.select("A1")

        XCTAssertEqual(currentValue(), "A1")
        XCTAssertEqual(rendererA?.isSelected, true)
        XCTAssertEqual(rendererB?.isSelected, false)

        coordinator.select("B1")

        XCTAssertEqual(currentValue(), "B1")
        XCTAssertEqual(rendererA?.isSelected, false, "Previously selected zone should be deselected")
        XCTAssertEqual(rendererB?.isSelected, true)
    }

    func testSelectingNilClearsSelection() {
        let (binding, currentValue) = makeBinding(initial: "A1")
        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA], annotations: [], into: mapView)

        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubzoneOverlayRenderer
        XCTAssertEqual(rendererA?.isSelected, true)

        coordinator.select(nil)

        XCTAssertNil(currentValue())
        XCTAssertEqual(rendererA?.isSelected, false)
    }

    func testTappingASubzoneCoordinateSelectsIt() {
        let (binding, currentValue) = makeBinding(initial: nil)
        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA], annotations: [], into: mapView)

        // Exercises the same lookup handleMapTap(_:) uses, without needing
        // to simulate a live UITapGestureRecognizer/screen point conversion.
        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        coordinator.select(SubzoneHitTester.subzoneCode(at: coordinate, in: [zoneA]))

        XCTAssertEqual(currentValue(), "A1")
    }

    func testSyncSelectionNeverWritesToBinding() {
        var writeCount = 0
        var storedValue: String?
        let binding = Binding<String?>(
            get: { storedValue },
            set: { storedValue = $0; writeCount += 1 }
        )

        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA], annotations: [], into: mapView)
        _ = coordinator.mapView(mapView, rendererFor: zoneA)

        // Simulates SwiftUI calling updateUIView repeatedly, including with
        // a genuinely new value driven from elsewhere in the app.
        coordinator.syncSelection(nil)
        coordinator.syncSelection(nil)
        coordinator.syncSelection("A1")
        coordinator.syncSelection("A1")

        XCTAssertEqual(writeCount, 0, "syncSelection must never write to the binding")
        XCTAssertEqual(storedValue, nil, "syncSelection must not mutate the underlying value either")
    }

    func testSyncSelectionUpdatesRenderersEvenWithoutBindingWrite() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA], annotations: [], into: mapView)
        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubzoneOverlayRenderer

        XCTAssertEqual(rendererA?.isSelected, false)

        coordinator.syncSelection("A1")
        XCTAssertEqual(rendererA?.isSelected, true, "syncSelection should still update visuals")

        coordinator.syncSelection(nil)
        XCTAssertEqual(rendererA?.isSelected, false)
    }

    func testSyncSelectionIsANoOpWhenAlreadyMatching() {
        let (binding, _) = makeBinding(initial: "A1")
        let coordinator = SeaMapCoordinator(selectedSubzone: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(overlays: [zoneA], annotations: [], into: mapView)
        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubzoneOverlayRenderer

        XCTAssertEqual(rendererA?.isSelected, true)

        // Selection already matches the binding's initial value - this
        // should be a true no-op, not just "harmless to call again".
        coordinator.syncSelection("A1")
        XCTAssertEqual(rendererA?.isSelected, true)
    }
}
