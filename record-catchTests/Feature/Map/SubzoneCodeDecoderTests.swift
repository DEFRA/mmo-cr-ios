import XCTest
@testable import record_catch

final class SubzoneCodeDecoderTests: XCTestCase {

    func testDecodesValidProperties() {
        let json = #"{"sub_code": "SZ-12"}"#.data(using: .utf8)
        XCTAssertEqual(SubzoneCodeDecoder.decode(from: json), "SZ-12")
    }

    func testReturnsUnknownForNilData() {
        XCTAssertEqual(SubzoneCodeDecoder.decode(from: nil), SubzoneCodeDecoder.unknownCode)
    }

    func testReturnsUnknownForMissingKey() {
        let json = #"{"other_field": "value"}"#.data(using: .utf8)
        XCTAssertEqual(SubzoneCodeDecoder.decode(from: json), SubzoneCodeDecoder.unknownCode)
    }

    func testReturnsUnknownForMalformedJSON() {
        let json = "not json".data(using: .utf8)
        XCTAssertEqual(SubzoneCodeDecoder.decode(from: json), SubzoneCodeDecoder.unknownCode)
    }

    func testReturnsUnknownForWrongTypedValue() {
        let json = #"{"sub_code": 12}"#.data(using: .utf8)
        XCTAssertEqual(SubzoneCodeDecoder.decode(from: json), SubzoneCodeDecoder.unknownCode)
    }
}
