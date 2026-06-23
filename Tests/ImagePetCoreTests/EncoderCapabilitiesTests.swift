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
        XCTAssertEqual(capabilities.jpegEncodingModes, [.standard])
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

    func testAdvancedJPEGCapabilityIsExplicit() {
        let capabilities = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic, .webp],
            writableFormats: [.original, .jpeg, .png, .heic, .webp],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic, .webp],
            supportsBitstreamInspection: true,
            jpegEncodingModes: [.standard, .advanced]
        )

        XCTAssertTrue(capabilities.jpegEncodingModes.contains(.standard))
        XCTAssertTrue(capabilities.jpegEncodingModes.contains(.advanced))
    }
}
