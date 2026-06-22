import XCTest
@testable import ImagePetCore

final class ModelTests: XCTestCase {

    func testCompressionPresetProperties() {
        for preset in CompressionPreset.allCases {
            XCTAssertEqual(preset.id, preset.rawValue)
            XCTAssertFalse(preset.displayName.isEmpty)
            XCTAssertGreaterThan(preset.quality, 0.0)
            XCTAssertLessThanOrEqual(preset.quality, 1.0)
        }
        
        XCTAssertEqual(CompressionPreset.high.displayName, "High")
        XCTAssertEqual(CompressionPreset.balanced.displayName, "Balanced")
        XCTAssertEqual(CompressionPreset.small.displayName, "Small")
    }

    func testCompressionErrorDescriptionsAndMapping() {
        let errors: [CompressionError] = [
            .unsupportedImageFormat,
            .permissionDenied,
            .outputFolderUnavailable,
            .failedToDecodeImage,
            .failedToWriteOutputFile,
            .notEnoughDiskSpace,
            .skipped,
            .webPOutputUnavailable,
            .unknown
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }

        // Test Mapping of itself
        let mappedSelf = CompressionError.map(CompressionError.unsupportedImageFormat)
        XCTAssertEqual(mappedSelf, .unsupportedImageFormat)

        // Test NSError Mapping
        let permissionDeniedError1 = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: nil)
        XCTAssertEqual(CompressionError.map(permissionDeniedError1), .permissionDenied)

        let permissionDeniedError2 = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: nil)
        XCTAssertEqual(CompressionError.map(permissionDeniedError2), .permissionDenied)

        let diskSpaceError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError, userInfo: nil)
        XCTAssertEqual(CompressionError.map(diskSpaceError), .notEnoughDiskSpace)

        let missingFolderError1 = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
        XCTAssertEqual(CompressionError.map(missingFolderError1), .outputFolderUnavailable)

        let missingFolderError2 = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        XCTAssertEqual(CompressionError.map(missingFolderError2), .outputFolderUnavailable)

        let unknownCocoaError = NSError(domain: NSCocoaErrorDomain, code: 99999, userInfo: nil)
        XCTAssertEqual(CompressionError.map(unknownCocoaError), .unknown)

        let arbitraryError = NSError(domain: "custom_domain", code: 123, userInfo: nil)
        XCTAssertEqual(CompressionError.map(arbitraryError), .unknown)
    }

    func testImageJobProperties() {
        let inputURL = URL(fileURLWithPath: "/path/to/test_image.heic")
        let job = ImageJob(
            inputURL: inputURL,
            originalSize: 1000
        )

        XCTAssertEqual(job.fileName, "test_image.heic")
        XCTAssertNil(job.savedSize)
        XCTAssertNil(job.savedRatio)
        XCTAssertEqual(job.status, .pending)
        XCTAssertNil(job.errorMessage)

        var completedJob = job
        completedJob.compressedSize = 400
        completedJob.status = .done

        XCTAssertEqual(completedJob.savedSize, 600)
        XCTAssertEqual(completedJob.savedRatio, 0.6)

        var zeroSizeJob = job
        zeroSizeJob.originalSize = 0
        zeroSizeJob.compressedSize = 0
        XCTAssertNil(zeroSizeJob.savedRatio)

        var skippedJob = job
        skippedJob.status = .skipped
        skippedJob.errorMessage = "Compression skipped"
        XCTAssertEqual(skippedJob.status, .skipped)
        XCTAssertEqual(skippedJob.errorMessage, "Compression skipped")
        XCTAssertNil(skippedJob.compressedSize)
        XCTAssertNil(skippedJob.savedSize)
        XCTAssertNil(skippedJob.savedRatio)
    }
}
