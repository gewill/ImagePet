import XCTest
@testable import ImagePetCore

final class SupportedImageFormatTests: XCTestCase {
    func testAcceptsMVPInputFormatsCaseInsensitively() {
        let capabilities = EncoderCapabilities.nativeOnly
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.jpg"), capabilities: capabilities))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.JPEG"), capabilities: capabilities))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.png"), capabilities: capabilities))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.HEIC"), capabilities: capabilities))
    }

    func testRejectsNonMVPInputFormats() {
        let capabilities = EncoderCapabilities.nativeOnly
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.gif"), capabilities: capabilities))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/document.pdf"), capabilities: capabilities))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/vector.svg"), capabilities: capabilities))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.tiff"), capabilities: capabilities))
    }

    func testWebPInputFollowsReadCapabilityOnly() {
        let readOnlyWebP = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic, .webp],
            writableFormats: [.original, .jpeg, .png, .heic],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic],
            supportsBitstreamInspection: true
        )
        let writeOnlyWebP = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic],
            writableFormats: [.original, .jpeg, .png, .heic, .webp],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic, .webp],
            supportsBitstreamInspection: true
        )

        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.webp"), capabilities: readOnlyWebP))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.webp"), capabilities: writeOnlyWebP))
    }
}
