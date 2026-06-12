import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public protocol ImageCompressing: Sendable {
    func compress(
        inputURL: URL,
        outputDirectory: URL?,
        options: CompressionOptions
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
                        options: CompressionOptions(preset: preset, format: .jpeg, locationMode: .designated, suffix: "_compressed", maxDimension: .none, stripMetadata: true),
                        targetUTType: .jpeg
                    )
                }
            }.value
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            await allocator.release(outputURL)
            throw CompressionError.map(error)
        }
    }

    public func compress(
        inputURL: URL,
        outputDirectory: URL?,
        options: CompressionOptions
    ) async throws -> CompressionResult {
        guard SupportedImageFormat.isSupported(inputURL) else {
            throw CompressionError.unsupportedImageFormat
        }

        let inputAccess = inputURL.startAccessingSecurityScopedResource()
        defer {
            if inputAccess {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }

        // Determine output directory based on location mode
        let resolvedOutputDirectory: URL
        switch options.locationMode {
        case .overwrite:
            resolvedOutputDirectory = FileManager.default.temporaryDirectory
        case .originalFolder:
            resolvedOutputDirectory = inputURL.deletingLastPathComponent()
        case .designated:
            guard let dir = outputDirectory else {
                throw CompressionError.outputFolderUnavailable
            }
            resolvedOutputDirectory = dir
        }

        // Output directory access if not overwriting and not temp
        let outputAccess = (options.locationMode != .overwrite) ? resolvedOutputDirectory.startAccessingSecurityScopedResource() : false
        defer {
            if outputAccess {
                resolvedOutputDirectory.stopAccessingSecurityScopedResource()
            }
        }

        if options.locationMode != .overwrite {
            try validateOutputDirectory(resolvedOutputDirectory)
        }

        // Determine target UTType
        let targetUTType = options.format.targetUTType(for: inputURL)
        let targetExtension = targetUTType.preferredFilenameExtension ?? "jpg"

        // Resolve output URL
        let outputURL: URL
        if options.locationMode == .overwrite {
            outputURL = resolvedOutputDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false).appendingPathExtension(targetExtension)
        } else {
            outputURL = await allocator.reserveOutputURL(
                for: inputURL,
                in: resolvedOutputDirectory,
                suffix: options.suffix,
                targetExtension: targetExtension
            )
        }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try autoreleasepool {
                    try Self.compressSynchronously(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        options: options,
                        targetUTType: targetUTType
                    )
                }
            }.value

            if options.locationMode == .overwrite {
                let finalURL = inputURL
                let originalSize = try Self.fileSize(for: inputURL)
                
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: finalURL.path) {
                    _ = try fileManager.replaceItemAt(finalURL, withItemAt: outputURL, backupItemName: nil, options: [])
                } else {
                    try fileManager.moveItem(at: outputURL, to: finalURL)
                }
                
                let compressedSize = try Self.fileSize(for: finalURL)
                return CompressionResult(
                    inputURL: inputURL,
                    outputURL: finalURL,
                    originalSize: originalSize,
                    compressedSize: compressedSize
                )
            } else {
                return result
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            if options.locationMode != .overwrite {
                await allocator.release(outputURL)
            }
            throw CompressionError.map(error)
        }
    }

    private static func compressSynchronously(
        inputURL: URL,
        outputURL: URL,
        options: CompressionOptions,
        targetUTType: UTType
    ) throws -> CompressionResult {
        let originalSize = try fileSize(for: inputURL)
        try ensureLikelyDiskCapacity(for: originalSize, at: outputURL.deletingLastPathComponent())

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw CompressionError.failedToDecodeImage
        }

        let image = try makeStandardImage(from: source, maxDimension: options.maxDimension.intValue, targetUTType: targetUTType)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            targetUTType.identifier as CFString,
            1,
            nil
        ) else {
            throw CompressionError.failedToWriteOutputFile
        }

        var properties: [CFString: Any] = [:]

        // Quality applies to lossy formats (JPEG and HEIC)
        if targetUTType == .jpeg || targetUTType == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = options.preset.quality
        }

        if !options.stripMetadata {
            if let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                for (key, val) in originalProperties {
                    properties[key] = val
                }
                if targetUTType == .jpeg || targetUTType == .heic {
                    properties[kCGImageDestinationLossyCompressionQuality] = options.preset.quality
                }
            }
        } else {
            properties[kCGImagePropertyColorModel] = kCGImagePropertyColorModelRGB
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.failedToWriteOutputFile
        }

        let compressedSize = try fileSize(for: outputURL)

        if compressedSize >= originalSize {
            try? FileManager.default.removeItem(at: outputURL)
            throw CompressionError.skipped
        }

        return CompressionResult(
            inputURL: inputURL,
            outputURL: outputURL,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
    }

    private static func makeStandardImage(from source: CGImageSource, maxDimension: Int?, targetUTType: UTType) throws -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        var width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        var height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0

        var directImage: CGImage? = nil
        if width == 0 || height == 0 {
            directImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            if let image = directImage {
                width = image.width
                height = image.height
            }
        }

        let originalMaxPixelSize = max(width, height)
        guard originalMaxPixelSize > 0 else {
            throw CompressionError.failedToDecodeImage
        }

        let targetMaxPixelSize: Int
        if let maxDimension = maxDimension {
            targetMaxPixelSize = min(originalMaxPixelSize, maxDimension)
        } else {
            targetMaxPixelSize = originalMaxPixelSize
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        var transformedImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        if transformedImage == nil {
            transformedImage = directImage ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        guard let finalImage = transformedImage else {
            throw CompressionError.failedToDecodeImage
        }

        let targetHasAlpha = (targetUTType == .png || targetUTType == .heic)
        return try flattenToSRGB(finalImage, preserveAlpha: targetHasAlpha)
    }

    private static func flattenToSRGB(_ image: CGImage, preserveAlpha: Bool) throws -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        
        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast
        let targetHasAlpha = preserveAlpha && hasAlpha
        
        let bitmapInfo: UInt32
        if targetHasAlpha {
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        } else {
            bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        }

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
        if !targetHasAlpha {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
        }
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
