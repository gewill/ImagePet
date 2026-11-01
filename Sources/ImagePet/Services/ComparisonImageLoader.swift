import Foundation
import CoreGraphics
import ImageIO
import ImagePetCore

/// Serializes comparison decoding independently of compression and the main actor.
/// Images live only in the open comparison sheet; there is no persistent/full-queue cache.
actor ComparisonImageLoader {
    static let shared = ComparisonImageLoader()
    static let maximumFullResolutionPixels = 16_000_000

    struct Picture: Sendable {
        let image: CGImage
        let width: Int
        let height: Int
        let bytes: Int64
        var canLoadFullResolution: Bool {
            width > 0 && height > 0 && width <= ComparisonImageLoader.maximumFullResolutionPixels / height
        }
        var isFullResolution: Bool { image.width == width && image.height == height }
    }

    struct Pair: Sendable {
        let original: Picture?
        let output: Picture
        let originalUnavailableReason: String?
        var canLoadFullResolution: Bool {
            output.canLoadFullResolution && (original?.canLoadFullResolution ?? true)
        }
    }

    enum LoadError: LocalizedError {
        case unavailable
        case tooLarge
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Image unavailable. Check the file and folder access."
            case .tooLarge: return "This image is too large for full-resolution comparison. Use Fit."
            }
        }
    }

    func load(input: URL, output: URL, accessDirectory: URL?, fullResolution: Bool) throws -> Pair {
        try Task.checkCancellation()
        let grant = accessDirectory?.startAccessingSecurityScopedResource() ?? false
        defer { if grant { accessDirectory?.stopAccessingSecurityScopedResource() } }
        return try autoreleasepool {
            let result = try read(output, fullResolution: fullResolution)
            try Task.checkCancellation()
            if input.resolvingSymlinksInPath().standardizedFileURL == output.resolvingSymlinksInPath().standardizedFileURL {
                return Pair(original: nil, output: result, originalUnavailableReason: "Original was overwritten. Showing the saved result.")
            }
            do {
                let original = try read(input, fullResolution: fullResolution)
                try Task.checkCancellation()
                return Pair(original: original, output: result, originalUnavailableReason: nil)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return Pair(original: nil, output: result, originalUnavailableReason: "Original unavailable. Showing the saved result.")
            }
        }
    }

    private func read(_ url: URL, fullResolution: Bool) throws -> Picture {
        try Task.checkCancellation()
        let grant = url.startAccessingSecurityScopedResource()
        defer { if grant { url.stopAccessingSecurityScopedResource() } }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = (attributes[.size] as? NSNumber)?.int64Value, size <= 128 * 1024 * 1024 else { throw LoadError.tooLarge }
        let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        if properties == nil, url.pathExtension.lowercased() == "webp" {
            let data = try Data(contentsOf: url)
            let decoder = SwiftWebPDecodingEngine()
            let metadata = try decoder.inspect(data)
            guard metadata.width > 0, metadata.height > 0 else { throw LoadError.unavailable }
            if fullResolution, metadata.width > Self.maximumFullResolutionPixels / metadata.height {
                throw LoadError.tooLarge
            }
            let limit = fullResolution ? max(metadata.width, metadata.height) : 2048
            let image = try decoder.decodeCGImage(from: data, maxDimension: limit)
            try Task.checkCancellation()
            return Picture(image: image, width: metadata.width, height: metadata.height, bytes: size)
        }
        guard let source, let properties,
              let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int,
              rawWidth > 0, rawHeight > 0 else { throw LoadError.unavailable }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let rotated = (5...8).contains(orientation)
        let width = rotated ? rawHeight : rawWidth
        let height = rotated ? rawWidth : rawHeight
        if fullResolution, width > Self.maximumFullResolutionPixels / height { throw LoadError.tooLarge }
        let limit = fullResolution ? max(width, height) : min(2048, max(width, height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
            kCGImageSourceShouldCacheImmediately: true
        ]
        let image: CGImage
        if let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            image = decoded
        } else if url.pathExtension.lowercased() == "webp" {
            image = try SwiftWebPDecodingEngine().decodeCGImage(from: Data(contentsOf: url), maxDimension: limit)
        } else { throw LoadError.unavailable }
        try Task.checkCancellation()
        return Picture(image: image, width: width, height: height, bytes: Int64(size))
    }
}
