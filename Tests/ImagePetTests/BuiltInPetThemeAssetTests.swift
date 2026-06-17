import AppKit
import XCTest

final class BuiltInPetThemeAssetTests: XCTestCase {
    private let builtInThemes = [
        "Dog",
        "Pufferfish",
        "Squirrel",
        "Hamster",
        "Cat",
        "Rabbit"
    ]

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

    func testBuiltInPetThemesMatchAnimationBudget() throws {
        for theme in builtInThemes {
            try assertThemeAssetsMatchAnimationBudget(theme)
        }
    }

    private func assertThemeAssetsMatchAnimationBudget(_ theme: String) throws {
        let resourcesURL = themeResourcesURL(theme)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resourcesURL.path), "\(theme) theme folder should exist")
        var totalBytes = 0

        for spec in animationSpecs {
            XCTAssertLessThanOrEqual(spec.frames, 24)

            let folderURL = resourcesURL.appendingPathComponent(spec.name)
            let files = try FileManager.default
                .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            XCTAssertEqual(files.count, spec.frames, "\(theme)/\(spec.name) should have the expected frame count")

            var uniqueFrames = Set<Data>()
            for (index, fileURL) in files.enumerated() {
                XCTAssertEqual(fileURL.lastPathComponent, String(format: "frame_%03d.png", index))

                let frameData = try Data(contentsOf: fileURL)
                uniqueFrames.insert(frameData)

                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalBytes += values.fileSize ?? 0

                let image = try XCTUnwrap(NSImage(contentsOf: fileURL), "Missing PNG at \(fileURL.path)")
                let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
                XCTAssertEqual(cgImage.width, 256, "\(fileURL.path) should be 256 px wide")
                XCTAssertEqual(cgImage.height, 256, "\(fileURL.path) should be 256 px tall")
                XCTAssertTrue(hasVisiblePixels(cgImage), "\(theme)/\(spec.name)/\(fileURL.lastPathComponent) should not be blank")
            }

            XCTAssertGreaterThan(
                uniqueFrames.count,
                1,
                "\(theme)/\(spec.name) should contain animated frame variation, not duplicated placeholder frames"
            )
        }

        XCTAssertLessThanOrEqual(totalBytes, 3 * 1024 * 1024, "\(theme) theme should stay under the PRD 3 MB budget")
    }

    private func themeResourcesURL(_ theme: String) -> URL {
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return projectRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("ImagePet")
            .appendingPathComponent("Resources")
            .appendingPathComponent(theme)
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
