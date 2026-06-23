import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum AppleWebPCapabilityProbe {
    public static func canWriteWebP() -> Bool {
        let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return identifiers.contains("org.webmproject.webp") || identifiers.contains("public.webp")
    }
}

public struct AppleWebPEncodingEngine: Sendable {
    public init() {}

    public func encode(
        image: CGImage,
        source: ImageSourceMetadata,
        destinationTemporaryURL: URL,
        options: CompressionOptions
    ) throws {
        guard AppleWebPCapabilityProbe.canWriteWebP() else {
            throw CompressionError.webPOutputUnavailable
        }

        let uti = "org.webmproject.webp" as CFString
        guard let destination = CGImageDestinationCreateWithURL(
            destinationTemporaryURL as CFURL,
            uti,
            1,
            nil
        ) else {
            throw CompressionError.failedToWriteOutputFile
        }

        var properties: [CFString: Any] = [:]
        let quality = options.lossyQuality?.value ?? CompressionPreset.balanced.quality
        properties[kCGImageDestinationLossyCompressionQuality] = quality

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.failedToWriteOutputFile
        }
    }
}
