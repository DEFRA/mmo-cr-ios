import XCTest
import MapKit
import SwiftUI
@testable import record_catch

final class OfflineMapCoordinatorTests: XCTestCase {

    private func makeRectangleOverlay(
        subCode: String,
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) -> SubrectangleOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        return SubrectangleOverlay(
            multiPolygon: MKMultiPolygon([polygon]),
            properties: SubrectangleProperties(subCode: subCode, icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )
    }

    private func makeBinding(initial: SubrectangleProperties?) -> (Binding<SubrectangleProperties?>, () -> SubrectangleProperties?) {
        var storedValue = initial
        let binding = Binding<SubrectangleProperties?>(
            get: { storedValue },
            set: { storedValue = $0 }
        )
        return (binding, { storedValue })
    }

    private func makeLand(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> MapLandOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        return MapLandOverlay(multiPolygon: MKMultiPolygon([MKPolygon(coordinates: coordinates, count: coordinates.count)]))
    }

    func testSelectUpdatesBindingAndOnlyAffectedRenderers() {
        let (binding, currentValue) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let zoneB = makeRectangleOverlay(subCode: "B1", minLat: 55.0, maxLat: 56.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(
            landOverlays: [],
            subrectangleOverlays: [zoneA, zoneB],
            selectableSubrectangleOverlays: [zoneA, zoneB],
            subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []),
            into: mapView
        )

        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubrectangleOverlayRenderer
        let rendererB = coordinator.mapView(mapView, rendererFor: zoneB) as? SubrectangleOverlayRenderer

        XCTAssertEqual(rendererA?.isSelected, false)
        XCTAssertEqual(rendererB?.isSelected, false)

        coordinator.select(zoneA.properties)

        XCTAssertEqual(currentValue()?.subCode, "A1")
        XCTAssertEqual(rendererA?.isSelected, true)
        XCTAssertEqual(rendererB?.isSelected, false)

        coordinator.select(zoneB.properties)

        XCTAssertEqual(currentValue()?.subCode, "B1")
        XCTAssertEqual(rendererA?.isSelected, false, "Previously selected zone should be deselected")
        XCTAssertEqual(rendererB?.isSelected, true)
    }

    func testSelectingNilClearsSelection() {
        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let (binding, currentValue) = makeBinding(initial: zoneA.properties)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), into: mapView
        )

        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubrectangleOverlayRenderer
        XCTAssertEqual(rendererA?.isSelected, true)

        coordinator.select(nil)

        XCTAssertNil(currentValue())
        XCTAssertEqual(rendererA?.isSelected, false)
    }

    func testTappingASubrectangleCoordinateSelectsIt() {
        let (binding, currentValue) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), into: mapView
        )

        // Exercises the same lookup handleMapTap(_:) uses, without needing to simulate a live
        // UITapGestureRecognizer/screen point conversion.
        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        coordinator.select(SubrectangleHitTester.subrectangle(at: coordinate, in: [zoneA])?.properties)

        XCTAssertEqual(currentValue()?.subCode, "A1")
    }

    func testTappingOutsideEveryRectangleClearsSelection() {
        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let (binding, currentValue) = makeBinding(initial: zoneA.properties)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), into: mapView
        )

        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        coordinator.select(SubrectangleHitTester.subrectangle(at: coordinate, in: [zoneA])?.properties)

        XCTAssertNil(currentValue())
    }

    func testSyncSelectionNeverWritesToBinding() {
        var writeCount = 0
        var storedValue: SubrectangleProperties?
        let binding = Binding<SubrectangleProperties?>(
            get: { storedValue },
            set: { storedValue = $0; writeCount += 1 }
        )

        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), into: mapView
        )
        _ = coordinator.mapView(mapView, rendererFor: zoneA)

        // Simulates SwiftUI calling updateUIView repeatedly, including with a genuinely new value
        // driven from elsewhere in the app.
        coordinator.syncSelection(nil)
        coordinator.syncSelection(nil)
        coordinator.syncSelection(zoneA.properties)
        coordinator.syncSelection(zoneA.properties)

        XCTAssertEqual(writeCount, 0, "syncSelection must never write to the binding")
        XCTAssertNil(storedValue, "syncSelection must not mutate the underlying value either")
    }

    func testSyncSelectionUpdatesRenderersEvenWithoutBindingWrite() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), into: mapView
        )
        let rendererA = coordinator.mapView(mapView, rendererFor: zoneA) as? SubrectangleOverlayRenderer

        XCTAssertEqual(rendererA?.isSelected, false)

        coordinator.syncSelection(zoneA.properties)
        XCTAssertEqual(rendererA?.isSelected, true, "syncSelection should still update visuals")

        coordinator.syncSelection(nil)
        XCTAssertEqual(rendererA?.isSelected, false)
    }

    func testRendererForNonSubrectangleOverlayTypesReturnsAppropriateRenderer() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let tileOverlay = BlankOfflineTileOverlay()
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: tileOverlay) is MKTileOverlayRenderer)

        let landOverlay = MapLandOverlay(multiPolygon: MKMultiPolygon([
            MKPolygon(coordinates: [
                CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
                CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
                CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
            ], count: 3)
        ]))
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: landOverlay) is MapLandOverlayRenderer)

        let portsOverlay = PortsOverlay(markers: [])
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: portsOverlay) is PortsOverlayRenderer)
    }

    func testViewForAnnotationReturnsNilForNonSubrectangleAnnotations() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let plainAnnotation = MKPointAnnotation(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))

        XCTAssertNil(coordinator.mapView(mapView, viewFor: plainAnnotation))
    }

    func testSubrectangleEntirelyOnLandIsNeitherLabelledNorSelectable() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let inlandZone = makeRectangleOverlay(subCode: "LAND1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let seaZone = makeRectangleOverlay(subCode: "SEA1", minLat: 54.0, maxLat: 55.0, minLon: -8.0, maxLon: -7.0)
        // Comfortably covers the inland zone's whole bounding rect, but is nowhere near the sea zone.
        let land = makeLand(minLat: 53.0, maxLat: 56.0, minLon: -5.0, maxLon: -2.0)

        let seaAnnotation = SubrectangleAnnotation(subCode: "SEA1", coordinate: seaZone.labelCoordinate)

        // `selectableSubrectangleOverlays`/`subrectangleAnnotations` are supplied here exactly as
        // `OfflineMapView` would derive them (via `SubrectangleSeaOverlap`, or already-precomputed
        // from `PrecomputedMapLoader`) — the coordinator itself no longer recomputes sea overlap;
        // that computation is covered directly, at the unit level, by `SubrectangleSeaOverlapTests`.
        coordinator.load(
            landOverlays: [land],
            subrectangleOverlays: [inlandZone, seaZone],
            selectableSubrectangleOverlays: [seaZone],
            subrectangleAnnotations: [seaAnnotation],
            portsOverlay: PortsOverlay(markers: []),
            into: mapView
        )

        // Not labelled: only the sea-overlapping subrectangle's annotation was added to the map.
        XCTAssertEqual(mapView.annotations.count, 1)
        XCTAssertEqual((mapView.annotations.first as? SubrectangleAnnotation)?.subCode, "SEA1")

        // Both overlays still get a renderer/render — the grid boundary is still drawn for a
        // land-only subrectangle, only its label and selectability are gated.
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: inlandZone) is SubrectangleOverlayRenderer)
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: seaZone) is SubrectangleOverlayRenderer)

        // Not selectable: a tap anywhere within the inland-only zone's bounds must not select it.
        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        coordinator.select(SubrectangleHitTester.subrectangle(at: coordinate, in: [seaZone])?.properties)
        XCTAssertNil(binding.wrappedValue)
    }

    // MARK: - Port name labels

    func testViewForPortLabelAnnotationReturnsConfiguredNonInteractiveView() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let portAnnotation = PortLabelAnnotation(
            portCode: 678,
            name: "Abbotsbury",
            coordinate: CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6)
        )
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [], selectableSubrectangleOverlays: [], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), portLabelAnnotations: [portAnnotation], into: mapView
        )

        let view = coordinator.mapView(mapView, viewFor: portAnnotation) as? PortLabelAnnotationView

        XCTAssertNotNil(view)
        XCTAssertFalse(view?.canShowCallout ?? true)
        XCTAssertFalse(view?.isEnabled ?? true)
        XCTAssertFalse(view?.isUserInteractionEnabled ?? true)
    }

    func testPortLabelViewVisibilityFollowsRegionZoom() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()
        // MKMapView computes its region/span from its pixel bounds, so a zero-frame map view
        // (the default for a view never added to a window) can't reliably reflect a requested
        // region back out via `region.span` — give it a realistic on-screen size first.
        mapView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        let portAnnotation = PortLabelAnnotation(
            portCode: 678,
            name: "Abbotsbury",
            coordinate: CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6)
        )
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [], selectableSubrectangleOverlays: [], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: []), portLabelAnnotations: [portAnnotation], into: mapView
        )

        let view = coordinator.mapView(mapView, viewFor: portAnnotation) as? PortLabelAnnotationView

        mapView.setRegion(
            MKCoordinateRegion(center: portAnnotation.coordinate, span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)),
            animated: false
        )
        coordinator.mapView(mapView, regionDidChangeAnimated: false)
        XCTAssertEqual(view?.isHidden, true, "Zoomed out past the threshold, port names should be hidden")

        mapView.setRegion(
            MKCoordinateRegion(center: portAnnotation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)),
            animated: false
        )
        coordinator.mapView(mapView, regionDidChangeAnimated: false)
        XCTAssertEqual(view?.isHidden, false, "Zoomed in past the threshold, port names should be shown")
    }

    func testRendererForPortsOverlayNoLongerExposesShowsLabels() {
        let (binding, _) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let portsOverlay = PortsOverlay(markers: [])
        XCTAssertTrue(coordinator.mapView(mapView, rendererFor: portsOverlay) is PortsOverlayRenderer)
    }

    func testTappingAPortCoordinateNeverSelectsAnything() {
        // Ports must never be selectable: `handleMapTap`'s hit-testing only ever consults
        // `subrectangleOverlays`, so a port's coordinate — even one that isn't inside any
        // subrectangle — must never populate the selection binding.
        let (binding, currentValue) = makeBinding(initial: nil)
        let coordinator = OfflineMapCoordinator(selectedSubrectangle: binding)
        let mapView = MKMapView()

        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let portMarker = PortMarker(portCode: 678, name: "Abbotsbury", coordinate: CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6))
        coordinator.load(
            landOverlays: [], subrectangleOverlays: [zoneA], selectableSubrectangleOverlays: [zoneA], subrectangleAnnotations: [],
            portsOverlay: PortsOverlay(markers: [portMarker]),
            portLabelAnnotations: PortLabelAnnotation.annotations(for: [portMarker]),
            into: mapView
        )

        coordinator.select(SubrectangleHitTester.subrectangle(at: portMarker.coordinate, in: [zoneA])?.properties)

        XCTAssertNil(currentValue())
    }
}
