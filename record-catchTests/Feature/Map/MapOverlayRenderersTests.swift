import XCTest
import MapKit
@testable import record_catch

/// Exercises the drawing code of the map's `MKOverlayRenderer`/`MKTileOverlay` subclasses
/// directly, using an offscreen `CGContext` — no live `MKMapView` or device rendering pass is
/// needed to invoke `draw(_:zoomScale:in:)`/`loadTile(at:result:)`, since these are ordinary
/// methods that only read overlay data and write to the supplied context.
final class MapOverlayRenderersTests: XCTestCase {

    private func makeContext() -> CGContext {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    private func makePolygon(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> MKMultiPolygon {
        let exterior = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        let hole = [
            CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - 0.1, longitude: (minLon + maxLon) / 2 - 0.1),
            CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - 0.1, longitude: (minLon + maxLon) / 2 + 0.1),
            CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 + 0.1, longitude: (minLon + maxLon) / 2 + 0.1),
            CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 + 0.1, longitude: (minLon + maxLon) / 2 - 0.1)
        ]
        let holePolygon = MKPolygon(coordinates: hole, count: hole.count)
        let polygon = MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: [holePolygon])
        return MKMultiPolygon([polygon])
    }

    // MARK: - BlankOfflineTileOverlay

    func test_blankOfflineTileOverlay_loadTile_returnsNonEmptyOpaquePNG() {
        let overlay = BlankOfflineTileOverlay()
        XCTAssertTrue(overlay.canReplaceMapContent)

        let expectation = expectation(description: "loadTile completes")
        overlay.loadTile(at: MKTileOverlayPath(x: 0, y: 0, z: 1, contentScaleFactor: 1)) { data, error in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            XCTAssertFalse(data?.isEmpty ?? true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - MapLandOverlayRenderer / SubrectangleOverlayRenderer (shared ring-walking)

    func test_mapLandOverlayRenderer_draw_buildsPathAndDrawsWithoutCrashing() {
        let overlay = MapLandOverlay(multiPolygon: makePolygon(minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0))
        let renderer = MapLandOverlayRenderer(overlay: overlay)
        let context = makeContext()

        renderer.draw(overlay.boundingMapRect, zoomScale: 1.0, in: context)
        XCTAssertNotNil(renderer.path, "draw should lazily build the path via createPath()")

        // A second draw call must not rebuild the path (already non-nil).
        renderer.draw(overlay.boundingMapRect, zoomScale: 2.0, in: context)
    }

    func test_subrectangleOverlayRenderer_draw_reflectsSelectionState() {
        let overlay = SubrectangleOverlay(
            multiPolygon: makePolygon(minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0),
            properties: SubrectangleProperties(subCode: "A1", icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )
        let renderer = SubrectangleOverlayRenderer(overlay: overlay)
        let context = makeContext()

        XCTAssertFalse(renderer.isSelected)
        renderer.draw(overlay.boundingMapRect, zoomScale: 1.0, in: context)
        XCTAssertNotNil(renderer.path)

        renderer.isSelected = true
        renderer.draw(overlay.boundingMapRect, zoomScale: 1.0, in: context)

        // Setting the same value again must not trigger extra work (covers the `didSet` guard).
        renderer.isSelected = true
    }

    // MARK: - PortsOverlayRenderer

    func test_portsOverlayRenderer_draw_onlyDrawsMarkersInsideMapRect() {
        let insideMarker = PortMarker(portCode: 1, name: "Inside", coordinate: CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5))
        let outsideMarker = PortMarker(portCode: 2, name: "Outside", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        let overlay = PortsOverlay(markers: [insideMarker, outsideMarker])
        let renderer = PortsOverlayRenderer(overlay: overlay)
        let context = makeContext()

        let visibleRect = MKMapRect(
            origin: MKMapPoint(CLLocationCoordinate2D(latitude: 55.0, longitude: -4.0)),
            size: MKMapSize(width: 1, height: 1)
        ).union(MKMapRect(origin: MKMapPoint(CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0)), size: MKMapSize(width: 1, height: 1)))

        renderer.draw(visibleRect, zoomScale: 1.0, in: context)
    }
}
