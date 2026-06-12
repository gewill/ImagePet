import XCTest
@testable import ImagePetCore

final class CompressionPresetTests: XCTestCase {
    func testPresetQualitiesMatchMVP() {
        XCTAssertEqual(CompressionPreset.high.quality, 0.9)
        XCTAssertEqual(CompressionPreset.balanced.quality, 0.8)
        XCTAssertEqual(CompressionPreset.small.quality, 0.65)
    }
}
