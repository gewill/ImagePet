import XCTest
@testable import ImagePetCore

final class OutputNameAllocatorTests: XCTestCase {
    func testUsesInputExtensionInCompressedFileName() {
        let input = URL(fileURLWithPath: "/tmp/photo.heic")

        XCTAssertEqual(
            OutputNameAllocator.outputFileName(for: input),
            "photo-heic_compressed.jpg"
        )
    }

    func testReservesNumberedSuffixesForDiskAndBatchConflicts() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let existing = directory.appendingPathComponent("photo-png_compressed.jpg")
        FileManager.default.createFile(atPath: existing.path, contents: Data())

        let allocator = OutputNameAllocator()
        let input = URL(fileURLWithPath: "/tmp/photo.png")

        let first = await allocator.reserveOutputURL(for: input, in: directory)
        let second = await allocator.reserveOutputURL(for: input, in: directory)

        XCTAssertEqual(first.lastPathComponent, "photo-png_compressed-2.jpg")
        XCTAssertEqual(second.lastPathComponent, "photo-png_compressed-3.jpg")
    }
}
