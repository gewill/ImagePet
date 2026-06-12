import AppKit
import Foundation

@MainActor
enum OutputFolderPanel {
    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.message = "Choose where ImagePet writes compressed JPG files. You can create a folder named ImagePet Output."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.nameFieldStringValue = "ImagePet Output"

        return panel.runModal() == .OK ? panel.url : nil
    }
}
