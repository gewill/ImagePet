import XCTest
@testable import ImagePetCore

final class AppleFixtureCompressionTests: XCTestCase {
    func testCompressesLocalAppleFixturesWhenAvailable() async throws {
        let root = packageRoot()
        let fixtureRoot = root.appendingPathComponent("TestImages/Apple", isDirectory: true)
        let inputDirectories = [
            fixtureRoot.appendingPathComponent("originals", isDirectory: true),
            fixtureRoot.appendingPathComponent("derived", isDirectory: true)
        ]

        guard inputDirectories.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            throw XCTSkip("Local Apple fixtures are not present.")
        }

        let outputDirectory = fixtureRoot.appendingPathComponent("output-balanced", isDirectory: true)
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let inputs = inputDirectories
            .flatMap { directory in
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
            }
            .filter(SupportedImageFormat.isSupported)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(inputs.isEmpty)

        let compressor = ImageCompressor()
        var results: [CompressionResult] = []

        for input in inputs {
            let result = try await compressor.compress(
                inputURL: input,
                outputDirectory: outputDirectory,
                preset: .balanced
            )
            results.append(result)
        }

        let originalTotal = results.reduce(Int64(0)) { $0 + $1.originalSize }
        let compressedTotal = results.reduce(Int64(0)) { $0 + $1.compressedSize }
        let savedTotal = originalTotal - compressedTotal
        let savedRatio = originalTotal > 0 ? Double(savedTotal) / Double(originalTotal) : 0

        let formatCounts = Dictionary(grouping: inputs, by: { $0.pathExtension.lowercased() })
            .mapValues(\.count)

        XCTAssertEqual(results.count, inputs.count)
        XCTAssertGreaterThan(originalTotal, 0)
        XCTAssertGreaterThan(compressedTotal, 0)

        print(
            """
            Apple fixture compression summary:
            Inputs: \(inputs.count) \(formatCounts)
            Output directory: \(outputDirectory.path)
            Original: \(byteString(originalTotal))
            Compressed: \(byteString(compressedTotal))
            Saved: \(byteString(savedTotal)) (\(String(format: "%.1f", savedRatio * 100))%)
            """
        )
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
