import AppKit
import CoreGraphics
import Foundation
import mozjpeg

public struct MozJPEGEncodingEngine: Sendable {
    public enum Availability: Sendable, Equatable {
        case unavailable
        case available
    }

    public let availability: Availability

    public init(availability: Availability = .unavailable) {
        self.availability = availability
    }

    public func encode(
        image: CGImage,
        metadata: ImageSourceMetadata,
        quality: CompressionQuality,
        destinationTemporaryURL: URL
    ) throws {
        _ = metadata
        guard availability == .available else {
            throw CompressionError.advancedJPEGUnavailable
        }

        let imageSize = NSSize(width: image.width, height: image.height)
        let nsImage = NSImage(cgImage: image, size: imageSize)
        do {
            try nsImage.mozjpegRepresentation(
                at: destinationTemporaryURL,
                quality: Float(quality.value),
                progressive: true,
                useFastestDCT: false
            )
        } catch {
            throw CompressionError.failedToWriteOutputFile
        }
    }
}

enum MozJPEGCapabilityProbe {
    static func canEncode() -> Bool {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return false
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))

        guard let image = context.makeImage() else {
            return false
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(".imagepet-mozjpeg-smoke-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        do {
            try MozJPEGEncodingEngine(availability: .available).encode(
                image: image,
                metadata: ImageSourceMetadata(format: .jpeg, pixelWidth: image.width, pixelHeight: image.height, hasAlpha: false),
                quality: .custom(80),
                destinationTemporaryURL: temporaryURL
            )
            let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
            return (values.fileSize ?? 0) > 0
        } catch {
            return false
        }
    }
}
