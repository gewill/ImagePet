import AppKit
import SwiftUI

@main
struct ImagePetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ImagePetStore()

    var body: some Scene {
        WindowGroup("ImagePet") {
            ContentView(store: store)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Images...") {
                    store.chooseInputImages()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Choose Output Folder...") {
                    store.chooseOutputDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Compress More") {
                    store.compressMore()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(store.isProcessing)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
