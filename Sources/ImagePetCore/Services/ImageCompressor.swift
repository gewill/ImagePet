import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public protocol ImageCompressing: Sendable {
    func compress(
        inputURL: URL,
        outputDirectory: URL,
        preset: CompressionPreset
    ) async throws -> CompressionResult
}

public final class ImageCompressor: ImageCompressing, @unchecked Sendable {
    private let allocator: OutputNameAllocator

    public init(allocator: OutputNameAllocator = OutputNameAllocator()) {
        self.allocator = allocator
    }

    public func resetReservations() async {
        await allocator.reset()
    }

    public func compress(
        inputURL: URL,
        outputDirectory: URL,
        preset: CompressionPreset
    ) async throws -> CompressionResult {
        guard SupportedImageFormat.isSupported(inputURL) else {
            throw CompressionError.unsupportedImageFormat
        }

        let inputAccess = inputURL.startAccessingSecurityScopedResource()
        let outputAccess = outputDirectory.startAccessingSecurityScopedResource()
        defer {
            if inputAccess {
                inputURL.stopAccessingSecurityScopedResource()
            }
            if outputAccess {
                outputDirectory.stopAccessingSecurityScopedResource()
            }
        }

        try validateOutputDirectory(outputDirectory)

        let outputURL = await allocator.reserveOutputURL(for: inputURL, in: outputDirectory)

        do {
            return try await Task.detached(priority: .userInitiated) {
                try autoreleasepool {
                    try Self.compressSynchronously(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        preset: preset
                    )
                }
            }.value
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            await allocator.release(outputURL)
            throw CompressionError.map(error)
        }
    }

    private static func compressSynchronously(
        inputURL: URL,
        outputURL: URL,
        preset: CompressionPreset
    ) throws -> CompressionResult {
        let originalSize = try fileSize(for: inputURL)
        try ensureLikelyDiskCapacity(for: originalSize, at: outputURL.deletingLastPathComponent())

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw CompressionError.failedToDecodeImage
        }

        let image = try makeStandardSRGBImage(from: source)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw CompressionError.failedToWriteOutputFile
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: preset.quality,
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB
        ]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.failedToWriteOutputFile
        }

        var compressedSize = try fileSize(for: outputURL)

        // Fallback for JPG/JPEG input: if the compressed output is larger or equal in size,
        // copy the original file to outputURL to avoid increasing the size.
        let inputExtension = inputURL.pathExtension.lowercased()
        if inputExtension == "jpg" || inputExtension == "jpeg" {
            if compressedSize >= originalSize {
                try? FileManager.default.removeItem(at: outputURL)
                try FileManager.default.copyItem(at: inputURL, to: outputURL)
                compressedSize = originalSize
            }
        }

        return CompressionResult(
            inputURL: inputURL,
            outputURL: outputURL,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
    }

    private static func makeStandardSRGBImage(from source: CGImageSource) throws -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        var width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        var height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0

        // Fallback: If properties are missing, try creating a direct CGImage to query dimensions
        var directImage: CGImage? = nil
        if width == 0 || height == 0 {
            directImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            if let image = directImage {
                width = image.width
                height = image.height
            }
        }

        let maxPixelSize = max(width, height)

        guard maxPixelSize > 0 else {
            throw CompressionError.failedToDecodeImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        var transformedImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        if transformedImage == nil {
            // Fallback: If thumbnail generation failed, use the direct image if already created, or load it
            transformedImage = directImage ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        guard let finalImage = transformedImage else {
            throw CompressionError.failedToDecodeImage
        }

        return try flattenToSRGB(finalImage)
    }

    private static func flattenToSRGB(_ image: CGImage) throws -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CompressionError.failedToDecodeImage
        }

        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let outputImage = context.makeImage() else {
            throw CompressionError.failedToDecodeImage
        }

        return outputImage
    }

    private static func fileSize(for url: URL) throws -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = values.fileSize {
                return Int64(fileSize)
            }
        } catch {
            throw CompressionError.map(error)
        }

        throw CompressionError.unknown
    }

    private static func ensureLikelyDiskCapacity(for bytesNeeded: Int64, at directory: URL) throws {
        let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else {
            return
        }

        if available < bytesNeeded {
            throw CompressionError.notEnoughDiskSpace
        }
    }

    private func validateOutputDirectory(_ outputDirectory: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: outputDirectory.path, isDirectory: &isDirectory)

        guard exists, isDirectory.boolValue else {
            throw CompressionError.outputFolderUnavailable
        }
    }
}
