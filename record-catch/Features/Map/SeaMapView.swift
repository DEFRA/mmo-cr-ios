import MapKit
import SwiftUI

struct SeaMapView: UIViewRepresentable {

    @Binding var selectedSubzone: String?

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
        span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0)
    )

    private static let boundaryRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
        span: MKCoordinateSpan(latitudeDelta: 14.0, longitudeDelta: 12.0)
    )

    func makeCoordinator() -> SeaMapCoordinator {
        SeaMapCoordinator(selectedSubzone: $selectedSubzone)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(SeaMapCoordinator.handleMapTap(_:))
        )
        tapGesture.cancelsTouchesInView = false
        map.addGestureRecognizer(tapGesture)

        map.showsScale = false
        map.showsTraffic = false
        map.showsBuildings = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll

        let config = MKStandardMapConfiguration(emphasisStyle: .default)
        config.showsTraffic = false
        map.preferredConfiguration = config

        loadSubzones(into: map, coordinator: context.coordinator)

        map.setRegion(Self.initialRegion, animated: false)
        map.cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: Self.boundaryRegion)
        map.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 20_000,
            maxCenterCoordinateDistance: 2_500_000
        )

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Uses syncSelection(_:), not select(_:) - select(_:) writes to the
        // `selectedSubzone` binding, and mutating a binding from inside
        // updateUIView triggers SwiftUI's "Modifying state during view
        // update" warning even when the value is unchanged. syncSelection
        // only touches the renderer/annotation views, and no-ops entirely
        // if the selection already matches what's on screen.
        context.coordinator.syncSelection(selectedSubzone)
    }

    private func loadSubzones(into map: MKMapView, coordinator: SeaMapCoordinator) {
        do {
            let result = try GeoJSONSubzoneLoader.loadBundledSubzones()
            coordinator.load(overlays: result.overlays, annotations: result.annotations, into: map)
        } catch {
            print("❌ Failed to load subzones:", error)
        }
    }
}
