import Foundation
import CoreGraphics
import AppKit

struct ThemeCache {
    let frames: [PetAnimation: [CGImage]]
    private static let staticImageCache = ThemeStaticImageCache()
    
    static func load(themeName: String) -> ThemeCache {
        let resolvedThemeName = BuiltInPetTheme.resolvedTheme(named: themeName).id
        let startTime = DispatchTime.now()
        var loadedFrames: [PetAnimation: [CGImage]] = [:]
        
        guard let themeURL = findResourcesURL(themeName: resolvedThemeName) else {
            #if DEBUG
            print("[ThemeCache] Error: Could not locate resource folder for theme '\(resolvedThemeName)'")
            #endif
            return ThemeCache(frames: [:])
        }
        
        let fileManager = FileManager.default
        for animation in PetAnimation.allCases {
            let folderURL = themeURL.appendingPathComponent(animation.rawValue)
            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            let sortedFiles = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
            var cgImages: [CGImage] = []
            
            for fileURL in sortedFiles {
                if fileURL.pathExtension.lowercased() == "png" {
                    if let image = NSImage(contentsOf: fileURL),
                       let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        cgImages.append(cgImage)
                    }
                }
            }
            
            if !cgImages.isEmpty {
                loadedFrames[animation] = cgImages
            }
        }
        
        loadedFrames = trimmingTransparentPadding(in: loadedFrames)

        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let durationMs = Double(nanoTime) / 1_000_000.0
        
        #if DEBUG
        print("[ThemeCache] Loaded theme '\(resolvedThemeName)' in \(String(format: "%.2f", durationMs)) ms")
        if durationMs > 200 {
            print("[ThemeCache] WARNING: Theme loading took \(String(format: "%.2f", durationMs)) ms, exceeding the 200ms budget target.")
        }
        #endif
        
        return ThemeCache(frames: loadedFrames)
    }

    private static func trimmingTransparentPadding(in frames: [PetAnimation: [CGImage]]) -> [PetAnimation: [CGImage]] {
        let allFrames = frames.values.flatMap { $0 }
        guard let cropRect = visibleUnionRect(for: allFrames) else { return frames }

        return frames.mapValues { animationFrames in
            animationFrames.map { frame in
                frame.cropping(to: cropRect) ?? frame
            }
        }
    }

    private static func visibleUnionRect(for frames: [CGImage]) -> CGRect? {
        var unionRect: CGRect?

        for frame in frames {
            guard let visibleRect = visibleRect(for: frame) else { continue }
            unionRect = unionRect.map { $0.union(visibleRect) } ?? visibleRect
        }

        guard let unionRect,
              let firstFrame = frames.first else {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: firstFrame.width, height: firstFrame.height)
        let integralRect = unionRect.integral.intersection(imageBounds)
        guard integralRect.width > 0,
              integralRect.height > 0,
              integralRect != imageBounds else {
            return nil
        }

        return integralRect
    }

    private static func visibleRect(for image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let alpha = pixels[rowStart + x * bytesPerPixel + 3]
                if alpha > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX,
              maxY >= minY else {
            return nil
        }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
    
    static func loadStaticImage(themeName: String, animation: PetAnimation = .idle) -> CGImage? {
        let resolvedThemeName = BuiltInPetTheme.resolvedTheme(named: themeName).id

        if let cachedImage = staticImageCache.image(themeName: resolvedThemeName, animation: animation) {
            return cachedImage
        }

        guard let themeURL = findResourcesURL(themeName: resolvedThemeName) else { return nil }
        let cropRect = staticImageCache.cropRect(themeName: resolvedThemeName) {
            loadVisibleUnionRect(themeURL: themeURL)
        }
        let folderURL = themeURL.appendingPathComponent(animation.rawValue)
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }
        let sortedFiles = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for fileURL in sortedFiles {
            if fileURL.pathExtension.lowercased() == "png" {
                if let image = NSImage(contentsOf: fileURL),
                   let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let trimmedImage = cropRect.flatMap { cgImage.cropping(to: $0) } ?? cgImage
                    staticImageCache.setImage(trimmedImage, themeName: resolvedThemeName, animation: animation)
                    return trimmedImage
                }
            }
        }
        return nil
    }

    private static func loadVisibleUnionRect(themeURL: URL) -> CGRect? {
        var loadedFrames: [CGImage] = []
        let fileManager = FileManager.default

        for animation in PetAnimation.allCases {
            let folderURL = themeURL.appendingPathComponent(animation.rawValue)
            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }

            let sortedFiles = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
            for fileURL in sortedFiles where fileURL.pathExtension.lowercased() == "png" {
                if let image = NSImage(contentsOf: fileURL),
                   let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    loadedFrames.append(cgImage)
                }
            }
        }

        return visibleUnionRect(for: loadedFrames)
    }
    
    private static func findResourcesURL(themeName: String) -> URL? {
        // 1. Try Package.swift module bundle if available
        #if SWIFT_PACKAGE
        let moduleBundle = Bundle.module
        if let url = moduleBundle.url(forResource: themeName, withExtension: nil) {
            return url
        }
        if let url = moduleBundle.url(forResource: themeName, withExtension: nil, subdirectory: "Resources") {
            return url
        }
        #endif
        
        // 2. Try main bundle resource locations
        if let url = Bundle.main.url(forResource: themeName, withExtension: nil) {
            return url
        }
        if let url = Bundle.main.url(forResource: themeName, withExtension: nil, subdirectory: "Resources") {
            return url
        }
        
        if let resourceURL = Bundle.main.resourceURL {
            let directTheme = resourceURL.appendingPathComponent(themeName)
            if FileManager.default.fileExists(atPath: directTheme.path) {
                return directTheme
            }
            let subTheme = resourceURL.appendingPathComponent("Resources").appendingPathComponent(themeName)
            if FileManager.default.fileExists(atPath: subTheme.path) {
                return subTheme
            }
            
            // XcodeGen sometimes compiles resource bundles as ImagePet_ImagePet.bundle
            let xcodeBundleURL = resourceURL.appendingPathComponent("ImagePet_ImagePet.bundle")
            if let bundle = Bundle(url: xcodeBundleURL) {
                if let url = bundle.url(forResource: themeName, withExtension: nil) {
                    return url
                }
            }
        }
        
        return nil
    }
}

private final class ThemeStaticImageCache: @unchecked Sendable {
    private let lock = NSLock()
    private var images: [String: CGImage] = [:]
    private var cropRects: [String: CachedCropRect] = [:]

    func image(themeName: String, animation: PetAnimation) -> CGImage? {
        lock.withLock {
            images[imageKey(themeName: themeName, animation: animation)]
        }
    }

    func setImage(_ image: CGImage, themeName: String, animation: PetAnimation) {
        lock.withLock {
            images[imageKey(themeName: themeName, animation: animation)] = image
        }
    }

    func cropRect(themeName: String, loader: () -> CGRect?) -> CGRect? {
        lock.lock()
        if let cached = cropRects[themeName] {
            lock.unlock()
            return cached.value
        }
        lock.unlock()

        let cropRect = loader()

        lock.withLock {
            cropRects[themeName] = cropRect.map(CachedCropRect.rect) ?? .none
        }

        return cropRect
    }

    private func imageKey(themeName: String, animation: PetAnimation) -> String {
        "\(themeName)::\(animation.rawValue)"
    }

    private enum CachedCropRect {
        case none
        case rect(CGRect)

        var value: CGRect? {
            switch self {
            case .none:
                return nil
            case .rect(let rect):
                return rect
            }
        }
    }
}
