import Foundation
import CoreGraphics
import ImageIO
import ImagePetCore

public actor ThumbnailGenerator {
    private let maxConcurrent: Int
    private var activeCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(maxConcurrent: Int = 3) {
        self.maxConcurrent = maxConcurrent
    }

    public func generate(for url: URL, maxPixelSize: CGFloat = 160) async -> CGImage? {
        if Task.isCancelled { return nil }

        await acquire()

        if Task.isCancelled {
            release()
            return nil
        }

        defer {
            release()
        }

        return await Self.performGenerate(for: url, maxPixelSize: maxPixelSize)
    }

    private static func performGenerate(for url: URL, maxPixelSize: CGFloat) async -> CGImage? {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return cgImage
        }

        // WebP fallback
        if url.pathExtension.lowercased() == "webp" {
            do {
                let data = try Data(contentsOf: url)
                let engine = SwiftWebPDecodingEngine()
                return try engine.decodeCGImage(from: data, maxDimension: Int(maxPixelSize))
            } catch {
                #if DEBUG
                print("[ThumbnailGenerator] Fallback WebP thumbnail generation failed: \(error)")
                #endif
            }
        }

        return nil
    }

    private func acquire() async {
        if activeCount < maxConcurrent {
            activeCount += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            activeCount = max(0, activeCount - 1)
        }
    }
}
