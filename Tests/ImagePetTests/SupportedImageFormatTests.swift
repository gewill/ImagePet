import XCTest
@testable import ImagePetCore

final class SupportedImageFormatTests: XCTestCase {
    func testAcceptsMVPInputFormatsCaseInsensitively() {
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.jpg")))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.JPEG")))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.png")))
        XCTAssertTrue(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.HEIC")))
    }

    func testRejectsNonMVPInputFormats() {
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.gif")))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/photo.webp")))
        XCTAssertFalse(SupportedImageFormat.isSupported(URL(fileURLWithPath: "/tmp/document.pdf")))
    }
}
