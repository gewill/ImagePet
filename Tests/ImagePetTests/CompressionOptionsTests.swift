import XCTest
@testable import ImagePetCore

final class CompressionOptionsTests: XCTestCase {
    func testLossyFormatsKeepQuality() {
        XCTAssertEqual(
            CompressionOptions(lossyQuality: .custom(80), format: .jpeg).lossyQuality,
            .custom(80)
        )
        XCTAssertEqual(
            CompressionOptions(lossyQuality: .custom(80), format: .heic).lossyQuality,
            .custom(80)
        )
        XCTAssertEqual(
            CompressionOptions(lossyQuality: .custom(80), format: .webp).lossyQuality,
            .custom(80)
        )
    }

    func testPNGOutputClearsLossyQuality() {
        let options = CompressionOptions(lossyQuality: .custom(80), format: .png)
        XCTAssertNil(options.lossyQuality)
    }

    func testJPEGEncodingModeDefaultsToStandard() {
        let options = CompressionOptions(format: .jpeg)
        XCTAssertEqual(options.jpegEncodingMode, .standard)
    }

    func testJPEGEncodingModeCanBeAdvanced() {
        let options = CompressionOptions(format: .jpeg, jpegEncodingMode: .advanced)
        XCTAssertEqual(options.jpegEncodingMode, .advanced)
    }
}
