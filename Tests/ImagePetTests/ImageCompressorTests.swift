import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ImagePetCore

final class ImageCompressorTests: XCTestCase {
    func testCompressesPNGToJPGOutput() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)

        let compressor = ImageCompressor()
        let result = try await compressor.compress(
            inputURL: inputURL,
            outputDirectory: directory,
            preset: .balanced
        )

        XCTAssertEqual(result.outputURL.pathExtension.lowercased(), "jpg")
        XCTAssertEqual(result.outputURL.lastPathComponent, "sample-png_compressed.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertGreaterThan(result.originalSize, 0)
        XCTAssertGreaterThan(result.compressedSize, 0)
    }

    func testRejectsUnsupportedInputFormat() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.gif")
        try Data("not an MVP input".utf8).write(to: inputURL)

        do {
            _ = try await ImageCompressor().compress(
                inputURL: inputURL,
                outputDirectory: directory,
                preset: .balanced
            )
            XCTFail("Expected unsupported input to fail")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .unsupportedImageFormat)
        }
    }

    func testReportsCorruptImageAsDecodeFailure() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("broken.png")
        try Data("not image data".utf8).write(to: inputURL)

        do {
            _ = try await ImageCompressor().compress(
                inputURL: inputURL,
                outputDirectory: directory,
                preset: .balanced
            )
            XCTFail("Expected corrupt image to fail")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .failedToDecodeImage)
            let outputURL = directory.appendingPathComponent("broken-png_compressed.jpg")
            XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
        }
    }

    func testReportsUnavailableOutputFolder() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)

        let missingOutputDirectory = directory.appendingPathComponent("missing", isDirectory: true)

        do {
            _ = try await ImageCompressor().compress(
                inputURL: inputURL,
                outputDirectory: missingOutputDirectory,
                preset: .balanced
            )
            XCTFail("Expected unavailable output folder to fail")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .outputFolderUnavailable)
        }
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeSamplePNG(to url: URL) throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 256,
            height: 160,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create bitmap context")
            return
        }

        for y in 0..<160 {
            for x in 0..<256 {
                let red = CGFloat((x * 7 + y * 3) % 255) / 255
                let green = CGFloat((x * 5 + y * 11) % 255) / 255
                let blue = CGFloat((x * 13 + y * 17) % 255) / 255
                context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
              ) else {
            XCTFail("Failed to create PNG destination")
            return
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            XCTFail("Failed to write PNG")
            return
        }
    }

    func testJPGCompressionFallbackWhenCompressedSizeIsLarger() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.jpg")
        // Write a tiny, low-quality JPG
        try Self.writeSampleJPG(to: inputURL, quality: 0.05)

        let compressor = ImageCompressor()
        do {
            _ = try await compressor.compress(
                inputURL: inputURL,
                outputDirectory: directory,
                preset: .high // 0.9 quality, which is much higher than 0.05, and will make the compressed size larger
            )
            XCTFail("Expected compression to be skipped when compressed size is larger")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .skipped)
            let expectedOutputURL = directory.appendingPathComponent("sample-jpg_compressed.jpg")
            XCTAssertFalse(FileManager.default.fileExists(atPath: expectedOutputURL.path))
        }
    }

    private static func writeSampleJPG(to url: URL, quality: Double) throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            XCTFail("Failed to create bitmap context")
            return
        }

        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            XCTFail("Failed to create JPEG destination")
            return
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            XCTFail("Failed to write JPEG")
            return
        }
    }
}

