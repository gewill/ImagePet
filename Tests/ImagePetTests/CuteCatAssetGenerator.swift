import AppKit
import XCTest

final class CuteCatAssetTests: XCTestCase {
    private let animationSpecs: [(name: String, frames: Int)] = [
        ("idle", 8),
        ("dragHover", 4),
        ("eating", 6),
        ("done", 12),
        ("issues", 8),
        ("stretch", 12),
        ("yawn", 10),
        ("petting", 8),
        ("sleep", 8)
    ]

    func testCuteCatAssetsMatchAnimationBudget() throws {
        let resourcesURL = try cuteCatResourcesURL()
        var totalBytes = 0

        for spec in animationSpecs {
            XCTAssertLessThanOrEqual(spec.frames, 24)

            let folderURL = resourcesURL.appendingPathComponent(spec.name)
            let files = try FileManager.default
                .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            XCTAssertEqual(files.count, spec.frames, "\(spec.name) should have the expected frame count")

            for (index, fileURL) in files.enumerated() {
                XCTAssertEqual(fileURL.lastPathComponent, String(format: "frame_%03d.png", index))

                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalBytes += values.fileSize ?? 0

                let image = try XCTUnwrap(NSImage(contentsOf: fileURL), "Missing PNG at \(fileURL.path)")
                let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
                XCTAssertEqual(cgImage.width, 256)
                XCTAssertEqual(cgImage.height, 256)
                XCTAssertTrue(hasVisiblePixels(cgImage), "\(fileURL.lastPathComponent) should not be blank")
            }
        }

        XCTAssertLessThanOrEqual(totalBytes, 3 * 1024 * 1024, "CuteCat theme should stay under the PRD 3 MB budget")
    }

    private func cuteCatResourcesURL() throws -> URL {
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return projectRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("ImagePet")
            .appendingPathComponent("Resources")
            .appendingPathComponent("CuteCat")
    }

    private func hasVisiblePixels(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }

        let length = CFDataGetLength(data)
        guard length >= 4 else { return false }

        var index = 3
        while index < length {
            if bytes[index] > 0 {
                return true
            }
            index += 4
        }
        return false
    }
}
