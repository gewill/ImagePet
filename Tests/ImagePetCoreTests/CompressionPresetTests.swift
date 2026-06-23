import XCTest
@testable import ImagePetCore

final class CompressionPresetTests: XCTestCase {
    func testPresetQualitiesMatchMVP() {
        XCTAssertEqual(CompressionPreset.high.quality, 0.9)
        XCTAssertEqual(CompressionPreset.balanced.quality, 0.8)
        XCTAssertEqual(CompressionPreset.small.quality, 0.65)
    }

    func testCustomQualityMapsIntegerPercentToFraction() {
        XCTAssertEqual(CompressionQuality.custom(80).value, 0.8)
        XCTAssertEqual(CompressionQuality.custom(10).value, 0.3)
        XCTAssertEqual(CompressionQuality.custom(99).value, 0.95)
    }
}
