import XCTest
import CoreGraphics
import Foundation
@testable import ImagePet
@testable import ImagePetCore

final class TaskCancellationAndThumbnailTests: XCTestCase {

    var testImageURL: URL {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/ImagePetTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // root/
        let fixtureURL = root.appendingPathComponent("TestImages/Apple/originals/iphone-17-pro-flower.jpg")
        if fm.fileExists(atPath: fixtureURL.path) {
            return fixtureURL
        }
        XCTFail("Could not locate iphone-17-pro-flower.jpg test fixture at \(fixtureURL.path)")
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("flower.jpg")
    }

    func testThumbnailGeneratorDecodesSuccessfully() async {
        let generator = ThumbnailGenerator(maxConcurrent: 3)
        let url = testImageURL

        let thumbnail = await generator.generate(for: url, maxPixelSize: 160)
        XCTAssertNotNil(thumbnail)
        XCTAssertLessThanOrEqual(thumbnail!.width, 160)
        XCTAssertLessThanOrEqual(thumbnail!.height, 160)
    }

    func testThumbnailGeneratorRespectsCancellation() async {
        let generator = ThumbnailGenerator(maxConcurrent: 3)
        let url = testImageURL

        let task = Task {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return await generator.generate(for: url, maxPixelSize: 160)
        }
        task.cancel()

        let result = await task.value
        XCTAssertNil(result, "Expected cancelled thumbnail generation to return nil")
    }

    @MainActor
    func testQueueCancellationStopScheduling() async {
        // Set environment variables to slow down the compressor for this test
        setenv("IS_UI_TESTING", "1", 1)
        setenv("UI_TEST_SLOW_PROCESS", "1", 1)
        defer {
            unsetenv("IS_UI_TESTING")
            unsetenv("UI_TEST_SLOW_PROCESS")
        }

        let store = ImagePetStore()

        // Add 5 jobs
        let url = testImageURL
        store.addDroppedURLs([url, url, url, url, url])

        XCTAssertEqual(store.jobs.count, 5)
        XCTAssertTrue(store.isProcessing)

        // Wait until at least one job is processing
        let startWait = Date().addingTimeInterval(2.0)
        while !store.jobs.contains(where: { $0.status == .processing }) && Date() < startWait {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        // Cancel
        store.cancelProcessing()
        XCTAssertTrue(store.isCanceling)

        // Wait for workers to finish current active jobs and exit
        let deadline = Date().addingTimeInterval(5.0)
        while store.isProcessing && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertFalse(store.isProcessing)
        XCTAssertFalse(store.isCanceling)

        // Verify states:
        // - At most maxConcurrentJobs (2) could be running and should finish as .done
        // - Remaining pending jobs must be marked .canceled
        let doneCount = store.jobs.filter { $0.status == .done }.count
        let canceledCount = store.jobs.filter { $0.status == .canceled }.count

        XCTAssertGreaterThan(doneCount, 0)
        XCTAssertGreaterThan(canceledCount, 0)
        XCTAssertEqual(doneCount + canceledCount, 5)

        // Verify Pet state is error/Stopped (issues state) due to canceled count
        let snapshot = store.petSnapshot
        XCTAssertEqual(snapshot.state, .issues)
        XCTAssertEqual(snapshot.title, "Stopped")
        XCTAssertTrue(snapshot.detail.contains("cancel"))
    }
}
