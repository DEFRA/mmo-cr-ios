import Foundation
import MapKit

// Standalone generator for the offline map's precomputed `.plist` resources — run as a macOS
// command-line script (via `swift`, compiling this file together with the real production Map
// source files listed in `scripts/generate-offline-map-data.sh`), so it reuses the exact same
// parsing/reprojection/sea-overlap logic the app ships and already unit-tests, rather than
// reimplementing it.
//
// Usage: swift <production Map .swift files...> generate-offline-map-data-main.swift <dataDir>
// `dataDir` is `record-catch/Features/Map/Data` — both the source of the `.geojson` inputs and
// the destination for the generated `-precomputed.plist` outputs.
//
// See `docs/development/offline-map-precomputed-data.md` for what this produces and why.

struct GeneratorError: Error, CustomStringConvertible {
    let description: String
}

func run() throws {
    guard CommandLine.arguments.count > 1 else {
        throw GeneratorError(description: "Usage: \(CommandLine.arguments[0]) <dataDir>")
    }
    let dataDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

    let mapData = try Data(contentsOf: dataDir.appendingPathComponent("map.geojson"))
    let subrectanglesData = try Data(contentsOf: dataDir.appendingPathComponent("subrectangles.geojson"))
    let portsData = try Data(contentsOf: dataDir.appendingPathComponent("ports.geojson"))

    let land = try MapLandLoader.load(from: mapData)
    let subResult = try SubrectangleLoader.load(from: subrectanglesData)
    let ports = try PortLoader.load(from: portsData)

    let selectable = SubrectangleSeaOverlap.overlappingSea(subResult.overlays, landOverlays: land)
    let selectableSubCodes = Set(selectable.map(\.subCode))

    let precomputedLand = PrecomputedMapData.LandLayer(
        landPolygons: land.map { PrecomputedMapData.MultiPolygon($0.multiPolygon) }
    )
    let precomputedSubs = subResult.overlays.map { overlay in
        PrecomputedMapData.Subrectangle(
            multiPolygon: PrecomputedMapData.MultiPolygon(overlay.multiPolygon),
            properties: overlay.properties,
            labelCoordinate: PrecomputedMapData.Coordinate(overlay.labelCoordinate),
            overlapsSea: selectableSubCodes.contains(overlay.subCode)
        )
    }
    let precomputedPorts = ports.map { port in
        PrecomputedMapData.Port(portCode: port.portCode, name: port.name, coordinate: PrecomputedMapData.Coordinate(port.coordinate))
    }

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary

    let landData = try encoder.encode(precomputedLand)
    let subData = try encoder.encode(PrecomputedMapData.SubrectangleLayer(subrectangles: precomputedSubs))
    let portData = try encoder.encode(PrecomputedMapData.PortLayer(ports: precomputedPorts))

    try landData.write(to: dataDir.appendingPathComponent("map-precomputed.plist"))
    try subData.write(to: dataDir.appendingPathComponent("subrectangles-precomputed.plist"))
    try portData.write(to: dataDir.appendingPathComponent("ports-precomputed.plist"))

    print("Generated precomputed map data:")
    print("  map-precomputed.plist:           \(land.count) land features, \(landData.count) bytes")
    print("  subrectangles-precomputed.plist: \(subResult.overlays.count) subrectangles (\(selectable.count) sea-overlapping), \(subData.count) bytes")
    print("  ports-precomputed.plist:         \(ports.count) ports, \(portData.count) bytes")
}

do {
    try run()
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
