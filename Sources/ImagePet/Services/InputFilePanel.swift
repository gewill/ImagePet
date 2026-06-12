import AppKit
import ImagePetCore
import UniformTypeIdentifiers

@MainActor
enum InputFilePanel {
    static func chooseImages() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Add Images"
        panel.message = "Choose JPG, PNG, or HEIC images to compress."
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
