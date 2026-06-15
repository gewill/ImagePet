import XCTest
@testable import ImagePetCore

final class EncoderCapabilitiesTests: XCTestCase {
    func testCapabilitiesKeepReadAndWriteFormatsSeparate() {
        let capabilities = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic, .webp],
            writableFormats: [.original, .jpeg, .png, .heic],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic],
            supportsBitstreamInspection: true
        )

        XCTAssertTrue(capabilities.readableFormats.contains(.webp))
        XCTAssertFalse(capabilities.writableFormats.contains(.webp))
    }

    func testAlphaCapabilityIsPerOutputFormat() {
        let capabilities = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic, .webp],
            writableFormats: [.original, .jpeg, .png, .heic, .webp],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic, .webp],
            supportsBitstreamInspection: true
        )

        XCTAssertFalse(capabilities.alphaCapableFormats.contains(.jpeg))
        XCTAssertTrue(capabilities.alphaCapableFormats.contains(.png))
        XCTAssertTrue(capabilities.alphaCapableFormats.contains(.webp))
        XCTAssertTrue(capabilities.supportsBitstreamInspection)
    }
}
