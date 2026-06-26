import AppKit
import XCTest

final class BuiltInPetThemeAssetTests: XCTestCase {
    private struct ThemeManifest: Decodable {
        struct CellSize: Decodable {
            let width: Int
            let height: Int
        }

        struct State: Decodable {
            let mode: String
            let recommendedFrames: Int
        }

        let schemaVersion: Int
        let themeId: String
        let displayName: String
        let description: String
        let defaultFPS: Int
        let cellSize: CellSize
        let assetFormat: String
        let states: [String: State]
    }

    private let builtInThemes = [
        "Dog",
        "Pufferfish",
        "Squirrel",
        "Hamster",
        "Cat",
        "Rabbit",
        "Clownfish"
    ]

    private let animationSpecs: [(name: String, frames: Int, mode: String)] = [
        ("idle", 8, "loop"),
        ("dragHover", 4, "loop"),
        ("eating", 6, "loop"),
        ("done", 12, "once"),
        ("issues", 8, "loop"),
        ("stretch", 12, "once"),
        ("yawn", 10, "once"),
        ("petting", 8, "loop"),
        ("sleep", 8, "loop")
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

        let manifest = try loadManifest(for: theme, resourcesURL: resourcesURL)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.themeId, theme)
        XCTAssertFalse(manifest.displayName.isEmpty)
        XCTAssertFalse(manifest.description.isEmpty)
        XCTAssertEqual(manifest.assetFormat, "png-sequence")
        XCTAssertEqual(manifest.cellSize.width, 256)
        XCTAssertEqual(manifest.cellSize.height, 256)
        XCTAssertTrue((8...12).contains(manifest.defaultFPS))
        XCTAssertEqual(Set(manifest.states.keys), Set(animationSpecs.map { $0.name }))

        for spec in animationSpecs {
            XCTAssertLessThanOrEqual(spec.frames, 24)
            let manifestState = try XCTUnwrap(manifest.states[spec.name], "\(theme) theme.json should include \(spec.name)")
            XCTAssertEqual(manifestState.mode, spec.mode, "\(theme)/\(spec.name) should declare the expected playback mode")
            XCTAssertEqual(manifestState.recommendedFrames, spec.frames, "\(theme)/\(spec.name) should declare the expected frame count")

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

    private func loadManifest(for theme: String, resourcesURL: URL) throws -> ThemeManifest {
        let manifestURL = resourcesURL.appendingPathComponent("theme.json")
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(ThemeManifest.self, from: data)
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
