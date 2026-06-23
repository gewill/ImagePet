import CoreGraphics
import Foundation
import ImageIO
import SwiftWebP

public struct ImageSourceMetadata: Sendable, Equatable {
    public let format: SupportedImageFormat
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let hasAlpha: Bool

    public init(format: SupportedImageFormat, pixelWidth: Int, pixelHeight: Int, hasAlpha: Bool) {
        self.format = format
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.hasAlpha = hasAlpha
    }
}

public struct WebPBitstreamMetadata: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let hasAlpha: Bool
    public let hasAnimation: Bool
}

public struct SwiftWebPEncodingEngine: Sendable {
    public let capabilities: EncoderCapabilities

    public init(capabilities: EncoderCapabilities = .current) {
        self.capabilities = capabilities
    }

    public func encode(
        image: CGImage,
        source: ImageSourceMetadata,
        destinationTemporaryURL: URL,
        options: CompressionOptions
    ) throws {
        guard capabilities.writableFormats.contains(.webp) else {
            throw CompressionError.webPOutputUnavailable
        }

        var config = WebPEncoderConfig.preset(
            .picture,
            quality: Float((options.lossyQuality ?? .preset(.balanced)).value * 100.0)
        )
        config.lossless = 0
        config.alphaCompression = 1
        config.alphaQuality = 100
        config.threadLevel = 1

        do {
            let rgba = try Self.makeUnpremultipliedRGBA(from: image)
            let data = try rgba.bytes.withUnsafeBufferPointer { buffer in
                try WebPEncoder().encode(
                    buffer,
                    format: .rgba,
                    config: config,
                    originWidth: rgba.width,
                    originHeight: rgba.height,
                    stride: rgba.bytesPerRow
                )
            }

            guard !data.isEmpty else {
                throw CompressionError.failedToWriteOutputFile
            }

            try data.write(to: destinationTemporaryURL, options: .atomic)
        } catch let error as CompressionError {
            throw error
        } catch {
            throw CompressionError.failedToWriteOutputFile
        }
    }

    private static func makeUnpremultipliedRGBA(from image: CGImage) throws -> RGBABuffer {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)

        try bytes.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw CompressionError.failedToDecodeImage
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var index = 0
        while index < bytes.count {
            let alpha = Int(bytes[index + 3])
            if alpha > 0 && alpha < 255 {
                bytes[index] = UInt8(min(255, Int(bytes[index]) * 255 / alpha))
                bytes[index + 1] = UInt8(min(255, Int(bytes[index + 1]) * 255 / alpha))
                bytes[index + 2] = UInt8(min(255, Int(bytes[index + 2]) * 255 / alpha))
            }
            index += bytesPerPixel
        }

        return RGBABuffer(width: width, height: height, bytesPerRow: bytesPerRow, bytes: bytes)
    }

    private struct RGBABuffer {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let bytes: [UInt8]
    }
}

public struct SwiftWebPDecodingEngine: Sendable {
    public let capabilities: EncoderCapabilities

    public init(capabilities: EncoderCapabilities = .current) {
        self.capabilities = capabilities
    }

    private static func isWebPData(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let riff = data.prefix(4)
        let webp = data.subdata(in: 8..<12)
        return riff == Data([0x52, 0x49, 0x46, 0x46]) && webp == Data([0x57, 0x45, 0x42, 0x50])
    }

    public func inspect(_ data: Data) throws -> WebPBitstreamMetadata {
        guard capabilities.readableFormats.contains(.webp) else {
            throw CompressionError.unsupportedImageFormat
        }
        guard Self.isWebPData(data) else {
            throw CompressionError.unsupportedImageFormat
        }

        // Try LibWebP first
        if capabilities.supportsBitstreamInspection {
            do {
                let feature = try WebPImageInspector.inspect(data)
                return WebPBitstreamMetadata(
                    width: feature.width,
                    height: feature.height,
                    hasAlpha: feature.hasAlpha,
                    hasAnimation: feature.hasAnimation
                )
            } catch {
                // Fall through to ImageIO
            }
        }

        // Fallback to ImageIO
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count = CGImageSourceGetCount(source)
            if count > 0,
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
                let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
                let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? NSNumber)?.boolValue ?? true
                if width > 0 && height > 0 {
                    return WebPBitstreamMetadata(
                        width: width,
                        height: height,
                        hasAlpha: hasAlpha,
                        hasAnimation: count > 1
                    )
                }
            }
        }

        throw CompressionError.failedToDecodeImage
    }

    public func decodeCGImage(from data: Data, maxDimension: Int?) throws -> CGImage {
        guard capabilities.readableFormats.contains(.webp) else {
            throw CompressionError.unsupportedImageFormat
        }

        let metadata = try inspect(data)
        if metadata.hasAnimation {
            throw CompressionError.unsupportedImageFormat
        }

        // Try WebPDecoder (LibWebP) first
        do {
            var options = WebPDecoderOptions()
            if let maxDimension, max(metadata.width, metadata.height) > maxDimension {
                let scale = Double(maxDimension) / Double(max(metadata.width, metadata.height))
                options.useScaling = true
                options.scaledWidth = max(1, Int(Double(metadata.width) * scale))
                options.scaledHeight = max(1, Int(Double(metadata.height) * scale))
            }
            return try WebPDecoder().decodeCGImage(from: data, options: options)
        } catch {
            // Fallback to ImageIO
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                var options: [CFString: Any] = [
                    kCGImageSourceShouldCache: false
                ]
                let needsThumbnail = maxDimension != nil && max(metadata.width, metadata.height) > (maxDimension ?? 0)
                if let maxDimension, needsThumbnail {
                    options[kCGImageSourceCreateThumbnailFromImageAlways] = true
                    options[kCGImageSourceThumbnailMaxPixelSize] = maxDimension
                    options[kCGImageSourceCreateThumbnailWithTransform] = true
                }

                if needsThumbnail {
                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                        return cgImage
                    }
                } else {
                    if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) {
                        return cgImage
                    }
                }
            }
            throw CompressionError.failedToDecodeImage
        }
    }
}

public extension EncoderCapabilities {
    static let current: EncoderCapabilities = SwiftWebPCapabilityProbe.current()
}

enum SwiftWebPCapabilityProbe {
    static func current() -> EncoderCapabilities {
        var readableFormats: Set<SupportedImageFormat> = [.jpeg, .png, .heic]
        var writableFormats: Set<OutputFormat> = [.original, .jpeg, .png, .heic]
        var alphaCapableFormats: Set<OutputFormat> = [.png, .heic]
        var supportsBitstreamInspection = false
        var jpegEncodingModes: Set<JPEGEncodingMode> = [.standard]

        if let image = makeSmokeImage(),
           let encoded = try? encodeSmokeImage(image),
           !encoded.isEmpty,
           let feature = try? WebPImageInspector.inspect(encoded) {
            supportsBitstreamInspection = true
            writableFormats.insert(.webp)
            if feature.width == image.width, feature.height == image.height {
                readableFormats.insert(.webp)
                alphaCapableFormats.insert(.webp)
            }
        }

        if AppleWebPCapabilityProbe.canWriteWebP() {
            writableFormats.insert(.webp)
            readableFormats.insert(.webp)
            alphaCapableFormats.insert(.webp)
        }

        if MozJPEGCapabilityProbe.canEncode() {
            jpegEncodingModes.insert(.advanced)
        }

        return EncoderCapabilities(
            readableFormats: readableFormats,
            writableFormats: writableFormats,
            supportsCustomQuality: true,
            alphaCapableFormats: alphaCapableFormats,
            supportsBitstreamInspection: supportsBitstreamInspection,
            jpegEncodingModes: jpegEncodingModes
        )
    }

    private static func encodeSmokeImage(_ image: CGImage) throws -> Data {
        let rgba = try SwiftWebPEncodingEngine.makeSmokeRGBA(from: image)
        let config = WebPEncoderConfig.preset(.picture, quality: 80)
        return try rgba.bytes.withUnsafeBufferPointer { buffer in
            try WebPEncoder().encode(
                buffer,
                format: .rgba,
                config: config,
                originWidth: rgba.width,
                originHeight: rgba.height,
                stride: rgba.bytesPerRow
            )
        }
    }

    private static func makeSmokeImage() -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        context.clear(CGRect(x: 0, y: 1, width: 1, height: 1))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
        return context.makeImage()
    }
}

private extension SwiftWebPEncodingEngine {
    static func makeSmokeRGBA(from image: CGImage) throws -> (width: Int, height: Int, bytesPerRow: Int, bytes: [UInt8]) {
        let mirror = try makeUnpremultipliedRGBA(from: image)
        return (mirror.width, mirror.height, mirror.bytesPerRow, mirror.bytes)
    }
}
