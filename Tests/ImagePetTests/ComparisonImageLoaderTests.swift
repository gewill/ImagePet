import Foundation
import ImageIO
import CoreGraphics
import Testing
import ImagePetCore
@testable import ImagePet

struct ComparisonImageLoaderTests {
    @Test func previewIsBoundedAndFullResolutionIsExact() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("original.png")
        let output = folder.appendingPathComponent("result.png")
        try image(at: input, width: 4096, height: 8)
        try FileManager.default.copyItem(at: input, to: output)
        let loader = ComparisonImageLoader()
        let preview = try await loader.load(input: input, output: output, accessDirectory: folder, fullResolution: false)
        #expect(preview.output.image.width == 2048)
        #expect(preview.output.width == 4096)
        #expect(preview.original != nil)
        #expect(preview.canLoadFullResolution)
        let full = try await loader.load(input: input, output: output, accessDirectory: folder, fullResolution: true)
        #expect(full.output.image.width == 4096)
        #expect(full.output.isFullResolution)
        #expect(full.original?.isFullResolution == true)
    }

    @Test func overwriteAndMissingOriginalShowOnlyResult() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appendingPathComponent("result.png")
        try image(at: output, width: 64, height: 32)
        let loader = ComparisonImageLoader()
        let overwritten = try await loader.load(input: output, output: output, accessDirectory: folder, fullResolution: false)
        #expect(overwritten.original == nil)
        #expect(overwritten.originalUnavailableReason?.contains("overwritten") == true)
        let missing = try await loader.load(input: folder.appendingPathComponent("missing.png"), output: output,
                                            accessDirectory: folder, fullResolution: false)
        #expect(missing.original == nil)
        #expect(missing.originalUnavailableReason?.contains("unavailable") == true)
        #expect(missing.output.width == 64)
    }

    @Test func honorsEXIFOrientation() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appendingPathComponent("rotated.jpg")
        try image(at: output, width: 64, height: 32, orientation: 6)
        let pair = try await ComparisonImageLoader().load(input: output, output: output, accessDirectory: folder, fullResolution: true)
        #expect(pair.output.width == 32)
        #expect(pair.output.height == 64)
        #expect(pair.output.image.width == 32)
        #expect(pair.output.image.height == 64)
    }

    @Test func cancellationStopsBeforeFileAccess() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ComparisonImageLoader().load(input: URL(fileURLWithPath: "/missing"),
                                                         output: URL(fileURLWithPath: "/missing"),
                                                         accessDirectory: nil, fullResolution: false)
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
        } catch {
            Issue.record("Expected CancellationError, received \(error)")
        }
    }

    @Test func webPComparisonAndMissingResult() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("original.png")
        let output = folder.appendingPathComponent("result.webp")
        try image(at: input, width: 64, height: 32)
        let source = try #require(CGImageSourceCreateWithURL(input as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        try SwiftWebPEncodingEngine().encode(image: decoded,
            source: ImageSourceMetadata(format: .png, pixelWidth: 64, pixelHeight: 32, hasAlpha: true),
            destinationTemporaryURL: output, options: CompressionOptions(format: .webp))
        let loader = ComparisonImageLoader()
        let pair = try await loader.load(input: input, output: output, accessDirectory: folder, fullResolution: true)
        #expect(pair.output.width == 64)
        #expect(pair.output.height == 32)
        #expect(pair.output.isFullResolution)
        #expect(pair.output.bytes == Int64(try Data(contentsOf: output).count))
        try FileManager.default.removeItem(at: output)
        await #expect(throws: (any Error).self) {
            try await loader.load(input: input, output: output, accessDirectory: folder, fullResolution: false)
        }
    }

    @Test func oversizedImageOffersPreviewButRejectsFullResolution() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appendingPathComponent("large.png")
        try image(at: output, width: 4097, height: 4097)
        let loader = ComparisonImageLoader()
        let pair = try await loader.load(input: output, output: output, accessDirectory: folder, fullResolution: false)
        #expect(pair.output.image.width == 2048)
        #expect(!pair.canLoadFullResolution)
        await #expect(throws: ComparisonImageLoader.LoadError.self) {
            try await loader.load(input: output, output: output, accessDirectory: folder, fullResolution: true)
        }
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func image(at url: URL, width: Int, height: Int, orientation: Int = 1) throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.6, green: 0.2, blue: 0.3, alpha: 0.6))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try #require(context.makeImage())
        let type = url.pathExtension == "jpg" ? "public.jpeg" : "public.png"
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
    }
}
