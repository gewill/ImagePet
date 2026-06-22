import XCTest
import AVFoundation

final class SoundManagerTests: XCTestCase {
    func testWavGenerationHasValidRIFFHeader() throws {
        // Retrieve or generate the WAV data
        let manager = SoundManager.shared
        
        // Use reflection or a test-specific accessor to get cached done wav data.
        // Since it's private, we can just invoke playSuccessSound() to ensure it doesn't crash,
        // or check the headers via reflection or modifying the visibility.
        // Actually, we can check it via Mirror.
        let mirror = Mirror(reflecting: manager)
        let cachedData = mirror.descendant("cachedDoneWavData") as? Data
        
        let data = try XCTUnwrap(cachedData, "WAV data should be generated and cached")
        
        // A valid WAV file is at least 44 bytes (header size)
        XCTAssertGreaterThanOrEqual(data.count, 44)
        
        // Verify RIFF header: "RIFF" at 0..4, "WAVE" at 8..12
        let riff = String(decoding: data[0..<4], as: UTF8.self)
        XCTAssertEqual(riff, "RIFF")
        
        let wave = String(decoding: data[8..<12], as: UTF8.self)
        XCTAssertEqual(wave, "WAVE")
        
        // Verify format chunk: "fmt " at 12..16
        let fmt = String(decoding: data[12..<16], as: UTF8.self)
        XCTAssertEqual(fmt, "fmt ")
        
        // Verify data chunk: "data" at 36..40 (assuming 16 bytes fmt chunk size)
        let dataStr = String(decoding: data[36..<40], as: UTF8.self)
        XCTAssertEqual(dataStr, "data")
    }
    
    func testPlaySuccessSoundDoesNotCrash() {
        // Verify playing the success sound is safe
        SoundManager.shared.playSuccessSound()
    }
}
