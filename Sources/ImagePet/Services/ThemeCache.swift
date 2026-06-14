import Foundation
import CoreGraphics
import AppKit

struct ThemeCache {
    let frames: [PetAnimation: [CGImage]]
    
    static func load(themeName: String) -> ThemeCache {
        let startTime = DispatchTime.now()
        var loadedFrames: [PetAnimation: [CGImage]] = [:]
        
        guard let themeURL = findResourcesURL(themeName: themeName) else {
            #if DEBUG
            print("[ThemeCache] Error: Could not locate resource folder for theme '\(themeName)'")
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
        
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let durationMs = Double(nanoTime) / 1_000_000.0
        
        #if DEBUG
        print("[ThemeCache] Loaded theme '\(themeName)' in \(String(format: "%.2f", durationMs)) ms")
        if durationMs > 200 {
            print("[ThemeCache] WARNING: Theme loading took \(String(format: "%.2f", durationMs)) ms, exceeding the 200ms budget target.")
        }
        #endif
        
        return ThemeCache(frames: loadedFrames)
    }
    
    static func loadStaticImage(themeName: String, animation: PetAnimation = .idle) -> CGImage? {
        guard let themeURL = findResourcesURL(themeName: themeName) else { return nil }
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
                    return cgImage
                }
            }
        }
        return nil
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
