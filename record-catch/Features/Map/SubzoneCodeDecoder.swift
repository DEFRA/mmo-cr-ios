import Foundation

/// Decodes a subzone's `sub_code` from a GeoJSON feature's raw `properties` payload.
enum SubzoneCodeDecoder {

    static let unknownCode = "Unknown"

    /// Returns the decoded `sub_code`, or `unknownCode` if `propertiesData` is
    /// missing, malformed, or doesn't contain a `sub_code` field.
    static func decode(from propertiesData: Data?) -> String {
        guard let propertiesData else {
            return unknownCode
        }

        do {
            let properties = try JSONDecoder().decode(SubzoneProperties.self, from: propertiesData)
            return properties.sub_code
        } catch {
            return unknownCode
        }
    }
}

struct SubzoneProperties: Decodable {
    let sub_code: String
}
