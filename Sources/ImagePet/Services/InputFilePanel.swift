import AppKit
import ImagePetCore
import UniformTypeIdentifiers

@MainActor
enum InputFilePanel {
    static func chooseImages() -> [URL] {
        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1" {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ImagePetUIInput-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let sample1 = tempDir.appendingPathComponent("sample1.png")
            let sample2 = tempDir.appendingPathComponent("sample2.png")
            
            func writeSamplePNG(to url: URL) throws {
                let size = NSSize(width: 100, height: 100)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor.blue.set()
                let rect = NSRect(origin: .zero, size: size)
                rect.fill()
                image.unlockFocus()
                
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "ImageGeneration", code: 1, userInfo: nil)
                }
                try pngData.write(to: url)
            }

            if ProcessInfo.processInfo.environment["UI_TEST_FAIL"] == "1" {
                let corruptPNG = tempDir.appendingPathComponent("badfile.png")
                try? "not image".write(to: corruptPNG, atomically: true, encoding: .utf8)
                return [corruptPNG]
            }

            var urls: [URL] = []
            if (try? writeSamplePNG(to: sample1)) != nil {
                urls.append(sample1)
            }
            if (try? writeSamplePNG(to: sample2)) != nil {
                urls.append(sample2)
            }

            return urls
        }

        let panel = NSOpenPanel()
        panel.title = "Add Images"
        panel.message = "Choose JPG, PNG, HEIC, or WebP images to compress."
        panel.prompt = "Add Images"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = allowedContentTypes

        return panel.runModal() == .OK ? panel.urls : []
    }

    private static var allowedContentTypes: [UTType] {
        SupportedImageFormat.supportedExtensions
            .compactMap { UTType(filenameExtension: $0) }
    }
}
