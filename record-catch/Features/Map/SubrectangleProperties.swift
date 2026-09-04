import Foundation

/// Properties preserved from a `subrectangles.geojson` feature.
///
/// `subCode` (`sub_code`) is the stable identifier the app uses to know which subrectangle was
/// selected — this is the value exposed back to the parent view via `OfflineMapView`'s
/// `selectedSubrectangle` binding. The remaining fields are preserved for future display/use but
/// are optional, since only `sub_code` is guaranteed present and correctly typed.
struct SubrectangleProperties: Codable, Equatable, Hashable {

    /// ICES statistical subrectangle code, e.g. `"27D86"`. Uniquely identifies the subrectangle.
    let subCode: String
    /// ICES rectangle name, e.g. `"27D8"`.
    let icesName: String?
    let areaKM2: Double?
    /// Dataset-supplied centre of the *parent* ICES rectangle (longitude). Shared by every
    /// subrectangle within that parent, so **not** used for this subrectangle's own label
    /// placement (see `SubrectangleOverlay.labelCoordinate`) — preserved only for possible future
    /// display/use.
    let statX: Double?
    /// Dataset-supplied centre of the *parent* ICES rectangle (latitude). See `statX`.
    let statY: Double?

    private enum CodingKeys: String, CodingKey {
        case subCode = "sub_code"
        case icesName = "ICESNAME"
        case areaKM2 = "AREA_KM2"
        case statX = "stat_x"
        case statY = "stat_y"
    }
}
