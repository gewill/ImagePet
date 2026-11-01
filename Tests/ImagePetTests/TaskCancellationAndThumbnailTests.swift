import XCTest
import CoreGraphics
import Foundation
@testable import ImagePet
@testable import ImagePetCore

final class TaskCancellationAndThumbnailTests: XCTestCase {

    private var fixtureDirectory: URL!
    private var testImageURL: URL { fixtureDirectory.appendingPathComponent("fixture.jpg") }

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: 512, height: 256, bitsPerComponent: 8,
                                            bytesPerRow: 512 * 4, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for x in 0..<512 {
            context.setFillColor(CGColor(red: CGFloat(x % 17) / 16, green: CGFloat(x % 23) / 22,
                                        blue: CGFloat(x % 31) / 30, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 256))
        }
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(testImageURL as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    override func tearDownWithError() throws {
        if let fixtureDirectory { try FileManager.default.removeItem(at: fixtureDirectory) }
        fixtureDirectory = nil
        try super.tearDownWithError()
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

    @MainActor
    func testThumbnailSizeAdjustmentDoesNotAffectJobs() {
        let store = ImagePetStore()
        let url = testImageURL
        store.addDroppedURLs([url])
        
        XCTAssertEqual(store.jobs.count, 1)
        let initialStatus = store.jobs[0].status
        
        store.thumbnailSize = .large
        XCTAssertEqual(store.thumbnailSize, .large)
        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertEqual(store.jobs[0].status, initialStatus)
    }

    @MainActor
    func testSingleItemDeletionUpdatesStatsAndCaches() async {
        let store = ImagePetStore()
        let url = testImageURL
        
        // Disable auto processing to inspect pending state deletion
        setenv("IS_UI_TESTING", "1", 1)
        defer { unsetenv("IS_UI_TESTING") }
        
        store.addDroppedURLs([url, url])
        XCTAssertEqual(store.jobs.count, 2)
        
        let jobIdToDelete = store.jobs[0].id
        // Add dummy thumbnail to cache
        let dummyImage = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
        store.thumbnails[jobIdToDelete] = dummyImage
        XCTAssertNotNil(store.thumbnails[jobIdToDelete])
        
        // Delete first job
        store.removeJob(id: jobIdToDelete)
        
        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertNotEqual(store.jobs[0].id, jobIdToDelete)
        XCTAssertNil(store.thumbnails[jobIdToDelete])
    }

    @MainActor
    func testRevealInFinderMissingFileShowsError() {
        let store = ImagePetStore()
        let job = ImageJob(inputURL: URL(fileURLWithPath: "/nonexistent/path.png"), originalSize: 100)
        
        XCTAssertNil(store.outputFolderMessage)
        store.revealInFinder(for: job)
        
        XCTAssertEqual(store.outputFolderMessage, "File not found")
    }
}
