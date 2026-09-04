import CoreLocation
import Foundation
import OSLog

/// Structured logging for offline map data loading failures.
///
/// A missing/corrupt bundled GeoJSON resource is a packaging/build defect, not user or catch
/// data, so it's safe to log the layer name and error description without redaction — see the
/// [security instructions](../../../.github/instructions/security.instructions.md) on never
/// logging personal data.
enum OfflineMapLogger {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "uk.gov.defra.catchrecording",
        category: "OfflineMap"
    )

    static func logLoadFailure(layer: String, error: Error) {
        logger.error("Failed to load offline map layer \(layer, privacy: .public): \(String(describing: error), privacy: .public)")
    }

    /// Debug-only aid for tuning `OfflineMapView`'s hard zoom limits (`maxZoomInDistance`/
    /// `maxZoomOutDistance`) by eye — no personal/catch data involved, just camera geometry, so
    /// `.public` privacy is fine here too. Callers gate this behind `#if DEBUG` themselves so it
    /// never runs (or costs anything) in a release build.
    static func logZoomLevel(distanceMetres: CLLocationDistance, latitudeDelta: Double, longitudeDelta: Double) {
        logger.debug(
            """
            Zoom: distance=\(Int(distanceMetres), privacy: .public)m \
            latitudeDelta=\(latitudeDelta, format: .fixed(precision: 4), privacy: .public) \
            longitudeDelta=\(longitudeDelta, format: .fixed(precision: 4), privacy: .public)
            """
        )
    }
}
