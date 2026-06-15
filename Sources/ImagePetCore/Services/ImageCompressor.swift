import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public protocol ImageCompressing: Sendable {
    func compress(
        inputURL: URL,
        outputDirectory: URL?,
        compressionOptions: CompressionOptions,
        saveOptions: SaveOptions
    ) async throws -> CompressionResult
}

public final class ImageCompressor: ImageCompressing, @unchecked Sendable {
    private let allocator: OutputNameAllocator
    private let capabilities: EncoderCapabilities
    private let webPEncodingEngine: SwiftWebPEncodingEngine
    private let webPDecodingEngine: SwiftWebPDecodingEngine

    public init(
        allocator: OutputNameAllocator = OutputNameAllocator(),
        capabilities: EncoderCapabilities = .current,
        webPEncodingEngine: SwiftWebPEncodingEngine? = nil,
        webPDecodingEngine: SwiftWebPDecodingEngine? = nil
    ) {
        self.allocator = allocator
        self.capabilities = capabilities
        self.webPEncodingEngine = webPEncodingEngine ?? SwiftWebPEncodingEngine(capabilities: capabilities)
        self.webPDecodingEngine = webPDecodingEngine ?? SwiftWebPDecodingEngine(capabilities: capabilities)
    }

    public func resetReservations() async {
        await allocator.reset()
    }

    public func compress(
        inputURL: URL,
        outputDirectory: URL,
        preset: CompressionPreset
    ) async throws -> CompressionResult {
        guard SupportedImageFormat.isSupported(inputURL, capabilities: capabilities) else {
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

        let finalOutputURL = await allocator.reserveOutputURL(for: inputURL, in: outputDirectory)
        let destinationTemporaryURL = Self.temporaryOutputURL(in: outputDirectory, targetExtension: "jpg")
        let options = CompressionOptions(lossyQuality: .preset(preset), format: .jpeg, maxDimension: .none, stripMetadata: true)

        do {
            return try await Task.detached(priority: .userInitiated) { [capabilities, webPEncodingEngine, webPDecodingEngine] in
                try autoreleasepool {
                    try Self.compressSynchronously(
                        inputURL: inputURL,
                        destinationTemporaryURL: destinationTemporaryURL,
                        finalOutputURL: finalOutputURL,
                        options: options,
                        targetOutputFormat: .jpeg,
                        capabilities: capabilities,
                        webPEncodingEngine: webPEncodingEngine,
                        webPDecodingEngine: webPDecodingEngine
                    )
                }
            }.value
        } catch {
            try? FileManager.default.removeItem(at: destinationTemporaryURL)
            await allocator.release(finalOutputURL)
            throw CompressionError.map(error)
        }
    }

    public func compress(
        inputURL: URL,
        outputDirectory: URL?,
        compressionOptions: CompressionOptions,
        saveOptions: SaveOptions
    ) async throws -> CompressionResult {
        guard SupportedImageFormat.isSupported(inputURL, capabilities: capabilities) else {
            throw CompressionError.unsupportedImageFormat
        }

        let inputAccess = inputURL.startAccessingSecurityScopedResource()
        defer {
            if inputAccess {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }

        let resolvedOutputDirectory: URL
        switch saveOptions.locationMode {
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

        let outputAccess = saveOptions.locationMode != .overwrite
            ? resolvedOutputDirectory.startAccessingSecurityScopedResource()
            : false
        defer {
            if outputAccess {
                resolvedOutputDirectory.stopAccessingSecurityScopedResource()
            }
        }

        if saveOptions.locationMode != .overwrite {
            try validateOutputDirectory(resolvedOutputDirectory)
        }

        let requestedFormat: OutputFormat = saveOptions.locationMode == .overwrite ? .original : compressionOptions.format
        let targetOutputFormat = try Self.resolveTargetOutputFormat(for: inputURL, requestedFormat: requestedFormat)

        guard capabilities.writableFormats.contains(targetOutputFormat) else {
            if targetOutputFormat == .webp {
                throw CompressionError.webPOutputUnavailable
            }
            throw CompressionError.failedToWriteOutputFile
        }

        let targetExtension = Self.targetExtension(
            for: inputURL,
            requestedFormat: requestedFormat,
            targetOutputFormat: targetOutputFormat
        )

        let finalOutputURL: URL
        if saveOptions.locationMode == .overwrite {
            finalOutputURL = resolvedOutputDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: false)
                .appendingPathExtension(targetExtension)
        } else {
            finalOutputURL = await allocator.reserveOutputURL(
                for: inputURL,
                in: resolvedOutputDirectory,
                suffix: saveOptions.suffix,
                targetExtension: targetExtension
            )
        }

        let destinationTemporaryURL = saveOptions.locationMode == .overwrite
            ? finalOutputURL
            : Self.temporaryOutputURL(in: resolvedOutputDirectory, targetExtension: targetExtension)

        let effectiveCompressionOptions = CompressionOptions(
            lossyQuality: compressionOptions.lossyQuality,
            format: targetOutputFormat,
            maxDimension: compressionOptions.maxDimension,
            stripMetadata: compressionOptions.stripMetadata
        )

        do {
            let result = try await Task.detached(priority: .userInitiated) { [capabilities, webPEncodingEngine, webPDecodingEngine] in
                try autoreleasepool {
                    try Self.compressSynchronously(
                        inputURL: inputURL,
                        destinationTemporaryURL: destinationTemporaryURL,
                        finalOutputURL: finalOutputURL,
                        options: effectiveCompressionOptions,
                        targetOutputFormat: targetOutputFormat,
                        capabilities: capabilities,
                        webPEncodingEngine: webPEncodingEngine,
                        webPDecodingEngine: webPDecodingEngine
                    )
                }
            }.value

            if saveOptions.locationMode == .overwrite {
                let originalSize = try Self.fileSize(for: inputURL)
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: inputURL.path) {
                    _ = try fileManager.replaceItemAt(inputURL, withItemAt: result.outputURL, backupItemName: nil, options: [])
                } else {
                    try fileManager.moveItem(at: result.outputURL, to: inputURL)
                }

                let compressedSize = try Self.fileSize(for: inputURL)
                return CompressionResult(
                    inputURL: inputURL,
                    outputURL: inputURL,
                    originalSize: originalSize,
                    compressedSize: compressedSize
                )
            }

            return result
        } catch {
            try? FileManager.default.removeItem(at: destinationTemporaryURL)
            if saveOptions.locationMode != .overwrite {
                await allocator.release(finalOutputURL)
            }
            throw CompressionError.map(error)
        }
    }

    private static func compressSynchronously(
        inputURL: URL,
        destinationTemporaryURL: URL,
        finalOutputURL: URL,
        options: CompressionOptions,
        targetOutputFormat: OutputFormat,
        capabilities: EncoderCapabilities,
        webPEncodingEngine: SwiftWebPEncodingEngine,
        webPDecodingEngine: SwiftWebPDecodingEngine
    ) throws -> CompressionResult {
        let originalSize = try fileSize(for: inputURL)
        try ensureLikelyDiskCapacity(for: originalSize, at: destinationTemporaryURL.deletingLastPathComponent())

        let preparedImage = try prepareImage(
            inputURL: inputURL,
            maxDimension: options.maxDimension.intValue,
            targetOutputFormat: targetOutputFormat,
            capabilities: capabilities,
            webPDecodingEngine: webPDecodingEngine
        )

        try encode(
            preparedImage: preparedImage,
            destinationTemporaryURL: destinationTemporaryURL,
            options: options,
            targetOutputFormat: targetOutputFormat,
            webPEncodingEngine: webPEncodingEngine
        )

        let compressedSize = try fileSize(for: destinationTemporaryURL)
        if compressedSize >= originalSize {
            try? FileManager.default.removeItem(at: destinationTemporaryURL)
            throw CompressionError.skipped
        }

        if destinationTemporaryURL != finalOutputURL {
            try FileManager.default.moveItem(at: destinationTemporaryURL, to: finalOutputURL)
        }

        return CompressionResult(
            inputURL: inputURL,
            outputURL: finalOutputURL,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
    }

    private static func prepareImage(
        inputURL: URL,
        maxDimension: Int?,
        targetOutputFormat: OutputFormat,
        capabilities: EncoderCapabilities,
        webPDecodingEngine: SwiftWebPDecodingEngine
    ) throws -> PreparedImage {
        guard let sourceFormat = SupportedImageFormat.format(for: inputURL) else {
            throw CompressionError.unsupportedImageFormat
        }

        if sourceFormat == .webp {
            guard capabilities.readableFormats.contains(.webp) else {
                throw CompressionError.unsupportedImageFormat
            }

            do {
                let data = try Data(contentsOf: inputURL)
                let metadata = try webPDecodingEngine.inspect(data)
                if metadata.hasAnimation {
                    throw CompressionError.unsupportedImageFormat
                }
                let decodedImage = try webPDecodingEngine.decodeCGImage(from: data, maxDimension: maxDimension)
                let standardImage = try flattenToSRGB(decodedImage, preserveAlpha: targetOutputFormat.preservesAlpha)
                let sourceMetadata = ImageSourceMetadata(
                    format: .webp,
                    pixelWidth: metadata.width,
                    pixelHeight: metadata.height,
                    hasAlpha: metadata.hasAlpha
                )
                return PreparedImage(image: standardImage, sourceMetadata: sourceMetadata, sourceProperties: nil)
            } catch let error as CompressionError {
                throw error
            } catch {
                throw CompressionError.failedToDecodeImage
            }
        }

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw CompressionError.failedToDecodeImage
        }

        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let image = try makeStandardImage(from: source, maxDimension: maxDimension, targetOutputFormat: targetOutputFormat)
        let sourceMetadata = ImageSourceMetadata(
            format: sourceFormat,
            pixelWidth: image.width,
            pixelHeight: image.height,
            hasAlpha: image.hasUsableAlpha
        )
        return PreparedImage(image: image, sourceMetadata: sourceMetadata, sourceProperties: sourceProperties)
    }

    private static func encode(
        preparedImage: PreparedImage,
        destinationTemporaryURL: URL,
        options: CompressionOptions,
        targetOutputFormat: OutputFormat,
        webPEncodingEngine: SwiftWebPEncodingEngine
    ) throws {
        if targetOutputFormat == .webp {
            try webPEncodingEngine.encode(
                image: preparedImage.image,
                source: preparedImage.sourceMetadata,
                destinationTemporaryURL: destinationTemporaryURL,
                options: options
            )
            return
        }

        try encodeWithImageIO(
            image: preparedImage.image,
            sourceProperties: preparedImage.sourceProperties,
            destinationTemporaryURL: destinationTemporaryURL,
            options: options,
            targetOutputFormat: targetOutputFormat
        )
    }

    private static func encodeWithImageIO(
        image: CGImage,
        sourceProperties: [CFString: Any]?,
        destinationTemporaryURL: URL,
        options: CompressionOptions,
        targetOutputFormat: OutputFormat
    ) throws {
        let targetUTType = targetOutputFormat.targetUTType(for: destinationTemporaryURL)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationTemporaryURL as CFURL,
            targetUTType.identifier as CFString,
            1,
            nil
        ) else {
            throw CompressionError.failedToWriteOutputFile
        }

        let quality = options.lossyQuality?.value ?? CompressionPreset.balanced.quality
        var properties: [CFString: Any] = [:]

        if targetOutputFormat.usesLossyQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }

        if !options.stripMetadata {
            sourceProperties?.forEach { key, value in
                properties[key] = value
            }
            if targetOutputFormat.usesLossyQuality {
                properties[kCGImageDestinationLossyCompressionQuality] = quality
            }
        } else {
            properties[kCGImagePropertyColorModel] = kCGImagePropertyColorModelRGB
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.failedToWriteOutputFile
        }
    }

    private static func makeStandardImage(from source: CGImageSource, maxDimension: Int?, targetOutputFormat: OutputFormat) throws -> CGImage {
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
        if let maxDimension {
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

        return try flattenToSRGB(finalImage, preserveAlpha: targetOutputFormat.preservesAlpha)
    }

    private static func flattenToSRGB(_ image: CGImage, preserveAlpha: Bool) throws -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let targetHasAlpha = preserveAlpha && image.hasUsableAlpha

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

    private static func resolveTargetOutputFormat(for inputURL: URL, requestedFormat: OutputFormat) throws -> OutputFormat {
        if requestedFormat != .original {
            return requestedFormat
        }

        guard let sourceFormat = SupportedImageFormat.format(for: inputURL) else {
            throw CompressionError.unsupportedImageFormat
        }

        switch sourceFormat {
        case .jpeg:
            return .jpeg
        case .png:
            return .png
        case .heic:
            return .heic
        case .webp:
            return .webp
        }
    }

    private static func targetExtension(
        for inputURL: URL,
        requestedFormat: OutputFormat,
        targetOutputFormat: OutputFormat
    ) -> String {
        if requestedFormat == .original {
            let originalExtension = inputURL.pathExtension.lowercased()
            if !originalExtension.isEmpty {
                return originalExtension
            }
        }
        return targetOutputFormat.targetExtension(for: inputURL)
    }

    private static func temporaryOutputURL(in directory: URL, targetExtension: String) -> URL {
        directory
            .appendingPathComponent(".imagepet-\(UUID().uuidString)", isDirectory: false)
            .appendingPathExtension(targetExtension)
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

    private struct PreparedImage {
        let image: CGImage
        let sourceMetadata: ImageSourceMetadata
        let sourceProperties: [CFString: Any]?
    }
}

private extension OutputFormat {
    var preservesAlpha: Bool {
        switch self {
        case .png, .heic, .webp:
            return true
        case .original, .jpeg:
            return false
        }
    }

    var usesLossyQuality: Bool {
        switch self {
        case .jpeg, .heic, .webp:
            return true
        case .original, .png:
            return false
        }
    }
}

private extension CGImage {
    var hasUsableAlpha: Bool {
        alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast
    }
}
