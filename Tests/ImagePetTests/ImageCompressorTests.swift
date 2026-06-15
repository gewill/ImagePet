import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ImagePetCore

final class ImageCompressorTests: XCTestCase {
    private static let webPCapabilities = EncoderCapabilities(
        readableFormats: [.jpeg, .png, .heic, .webp],
        writableFormats: [.original, .jpeg, .png, .heic, .webp],
        supportsCustomQuality: true,
        alphaCapableFormats: [.png, .heic, .webp],
        supportsBitstreamInspection: true
    )

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

    func testCompressesWithMaxDimensionConstraint() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("large.png")
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 2000,
            height: 1200,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1200))
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(inputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)

        let compressor = ImageCompressor()
        let compressionOptions = CompressionOptions(
            lossyQuality: .preset(.balanced),
            format: .jpeg,
            maxDimension: .p1024,
            stripMetadata: true
        )
        let saveOptions = SaveOptions(locationMode: .designated, suffix: "_resized")

        let result = try await compressor.compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: compressionOptions,
            saveOptions: saveOptions
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        
        let outputSource = CGImageSourceCreateWithURL(result.outputURL as CFURL, nil)!
        let outputProperties = CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any]
        let outputWidth = (outputProperties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let outputHeight = (outputProperties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        
        XCTAssertEqual(max(outputWidth, outputHeight), 1024)
        XCTAssertEqual(min(outputWidth, outputHeight), 614)
    }

    func testFormatsConversionHEICAndPNG() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)

        let compressor = ImageCompressor()
        
        let heicOptions = CompressionOptions(
            lossyQuality: .preset(.balanced),
            format: .heic,
            maxDimension: .none,
            stripMetadata: true
        )
        let heicSaveOptions = SaveOptions(locationMode: .designated, suffix: "_to_heic")
        let heicResult = try await compressor.compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: heicOptions,
            saveOptions: heicSaveOptions
        )
        XCTAssertEqual(heicResult.outputURL.pathExtension.lowercased(), "heic")
        XCTAssertTrue(FileManager.default.fileExists(atPath: heicResult.outputURL.path))

        let pngOptions = CompressionOptions(
            lossyQuality: .preset(.balanced),
            format: .png,
            maxDimension: .none,
            stripMetadata: true
        )
        let pngSaveOptions = SaveOptions(locationMode: .designated, suffix: "_to_png")
        
        do {
            let pngResult = try await compressor.compress(
                inputURL: inputURL,
                outputDirectory: directory,
                compressionOptions: pngOptions,
                saveOptions: pngSaveOptions
            )
            XCTAssertEqual(pngResult.outputURL.pathExtension.lowercased(), "png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: pngResult.outputURL.path))
        } catch let error as CompressionError {
            XCTAssertEqual(error, .skipped)
        }
    }

    func testCompressesPNGToWebPOutput() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)

        let compressor = ImageCompressor(capabilities: Self.webPCapabilities)
        let result = try await compressor.compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: CompressionOptions(lossyQuality: .custom(72), format: .webp),
            saveOptions: SaveOptions(locationMode: .designated, suffix: "_webp")
        )

        XCTAssertEqual(result.outputURL.pathExtension.lowercased(), "webp")
        XCTAssertEqual(result.outputURL.lastPathComponent, "sample_webp.webp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

        let metadata = try SwiftWebPDecodingEngine(capabilities: Self.webPCapabilities)
            .inspect(Data(contentsOf: result.outputURL))
        XCTAssertEqual(metadata.width, 256)
        XCTAssertEqual(metadata.height, 160)
        XCTAssertFalse(metadata.hasAnimation)
    }

    func testWebPInputOriginalReencodesAsWebP() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)

        let compressor = ImageCompressor(capabilities: Self.webPCapabilities)
        let firstResult = try await compressor.compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: CompressionOptions(lossyQuality: .custom(90), format: .webp),
            saveOptions: SaveOptions(locationMode: .designated, suffix: "_source")
        )

        let result = try await compressor.compress(
            inputURL: firstResult.outputURL,
            outputDirectory: directory,
            compressionOptions: CompressionOptions(lossyQuality: .custom(45), format: .original),
            saveOptions: SaveOptions(locationMode: .designated, suffix: "_again")
        )

        XCTAssertEqual(result.outputURL.pathExtension.lowercased(), "webp")
        XCTAssertEqual(result.outputURL.lastPathComponent, "sample_source_again.webp")
        XCTAssertLessThan(result.compressedSize, result.originalSize)
    }

    func testTransparentPNGToWebPPreservesClearAndSemiTransparentAlpha() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("alpha.png")
        try Self.writeAlphaPNG(to: inputURL)

        let result = try await ImageCompressor(capabilities: Self.webPCapabilities).compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: CompressionOptions(lossyQuality: .custom(80), format: .webp),
            saveOptions: SaveOptions(locationMode: .designated, suffix: "_webp")
        )

        let decoded = try SwiftWebPDecodingEngine(capabilities: Self.webPCapabilities)
            .decodeCGImage(from: Data(contentsOf: result.outputURL), maxDimension: nil)
        let rgba = try Self.rgbaBytes(from: decoded)
        let clearAlpha = Self.alpha(atX: 32, y: 128, width: decoded.width, bytes: rgba)
        let semiTransparentAlpha = Self.alpha(atX: 128, y: 128, width: decoded.width, bytes: rgba)

        XCTAssertLessThanOrEqual(clearAlpha, 10)
        XCTAssertGreaterThanOrEqual(semiTransparentAlpha, 80)
        XCTAssertLessThanOrEqual(semiTransparentAlpha, 180)
    }

    func testWebPOriginalSkipsWhenWebPWriteUnavailable() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.png")
        try Self.writeSamplePNG(to: inputURL)
        let sourceWebP = try await ImageCompressor(capabilities: Self.webPCapabilities).compress(
            inputURL: inputURL,
            outputDirectory: directory,
            compressionOptions: CompressionOptions(lossyQuality: .custom(80), format: .webp),
            saveOptions: SaveOptions(locationMode: .designated, suffix: "_source")
        ).outputURL

        let readOnlyWebP = EncoderCapabilities(
            readableFormats: [.jpeg, .png, .heic, .webp],
            writableFormats: [.original, .jpeg, .png, .heic],
            supportsCustomQuality: true,
            alphaCapableFormats: [.png, .heic],
            supportsBitstreamInspection: true
        )

        do {
            _ = try await ImageCompressor(capabilities: readOnlyWebP).compress(
                inputURL: sourceWebP,
                outputDirectory: directory,
                compressionOptions: CompressionOptions(lossyQuality: .custom(80), format: .original),
                saveOptions: SaveOptions(locationMode: .designated, suffix: "_again")
            )
            XCTFail("Expected WebP original output to be skipped when WebP write is unavailable")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .webPOutputUnavailable)
        }
    }

    func testOverwriteModeKeepsOriginalFormatWhenDifferentFormatIsSelected() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let inputURL = directory.appendingPathComponent("sample.jpg")
        try Self.writeLargeSampleJPG(to: inputURL, quality: 1.0)

        let compressionOptions = CompressionOptions(
            lossyQuality: .preset(.small),
            format: .png,
            maxDimension: .none,
            stripMetadata: true
        )
        let saveOptions = SaveOptions(locationMode: .overwrite, suffix: "_ignored")

        let result = try await ImageCompressor().compress(
            inputURL: inputURL,
            outputDirectory: nil,
            compressionOptions: compressionOptions,
            saveOptions: saveOptions
        )

        XCTAssertEqual(result.outputURL, inputURL)
        XCTAssertEqual(result.outputURL.pathExtension.lowercased(), "jpg")
        XCTAssertLessThan(result.compressedSize, result.originalSize)

        let outputSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil)
        XCTAssertEqual(CGImageSourceGetType(outputSource!) as String?, UTType.jpeg.identifier)
    }

    private static func writeLargeSampleJPG(to url: URL, quality: Double) throws {
        let width = 320
        let height = 240
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            XCTFail("Failed to create bitmap context")
            return
        }

        for y in 0..<height {
            for x in 0..<width {
                let red = CGFloat((x * 17 + y * 3) % 255) / 255
                let green = CGFloat((x * 7 + y * 19) % 255) / 255
                let blue = CGFloat((x * 13 + y * 11) % 255) / 255
                context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

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

    private static func writeAlphaPNG(to url: URL) throws {
        let width = 256
        let height = 256
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create bitmap context")
            return
        }

        for y in 0..<height {
            for x in 0..<width {
                let alpha: CGFloat
                if x < 85 {
                    alpha = 0
                } else if x < 170 {
                    alpha = 0.5
                } else {
                    alpha = 1
                }
                let red = CGFloat((x * 11 + y * 3) % 255) / 255
                let green = CGFloat((x * 5 + y * 17) % 255) / 255
                let blue = CGFloat((x * 19 + y * 7) % 255) / 255
                context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: alpha))
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

    private static func rgbaBytes(from image: CGImage) throws -> [UInt8] {
        let bytesPerRow = image.width * 4
        var bytes = [UInt8](repeating: 0, count: image.height * bytesPerRow)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        bytes.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                XCTFail("Failed to create RGBA context")
                return
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private static func alpha(atX x: Int, y: Int, width: Int, bytes: [UInt8]) -> UInt8 {
        bytes[((y * width) + x) * 4 + 3]
    }
}
