import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ImagePetCore

final class ImageCompressorTests: XCTestCase {
    func testCompressesPNGToJPGOutput() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
}
