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
                Button("Show Main Window") {
                    store.activateMainWindow()
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Add Images...") {
                    store.chooseInputImages()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Choose Output Folder...") {
                    store.chooseOutputDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button(store.isDesktopPetVisible ? "Hide Desktop Pet" : "Show Desktop Pet") {
                    store.toggleDesktopPet()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Compress More") {
                    store.compressMore()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(store.isProcessing)
            }
        }

        Window("ImagePet", id: "main") {
            ContentView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowUpdateObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let store = ImagePetStore.shared {
            let isUITesting = ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1"
            if store.launchMode == .loginItem {
                windowUpdateObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didUpdateNotification,
                    object: nil,
                    queue: .main
                ) { @MainActor _ in
                    for window in NSApp.windows {
                        let isMainWindow = window.title == "ImagePet" || window.identifier?.rawValue == "main"
                        if isMainWindow && store.launchMode == .loginItem && !store.hasReopened {
                            window.orderOut(nil)
                        }
                    }
                }

                if isUITesting {
                    NSApp.setActivationPolicy(.regular)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if store.isDesktopPetEnabled && store.isDesktopPetVisible {
                            store.attachDesktopPetControllerIfNeeded()
                        }
                    }
                } else {
                    NSApp.setActivationPolicy(.accessory)
                    if store.isDesktopPetEnabled && store.isDesktopPetVisible {
                        store.attachDesktopPetControllerIfNeeded()
                    } else {
                        // 静默启动但无需显示 Pet：异步将策略设为 .regular 以保持 Dock 图标正常存在，且抑制主窗口
                        DispatchQueue.main.async {
                            NSApp.setActivationPolicy(.regular)
                        }
                    }
                }
            } else {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                if isUITesting && store.isDesktopPetEnabled && store.isDesktopPetVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        store.attachDesktopPetControllerIfNeeded()
                    }
                } else {
                    if store.isDesktopPetEnabled && store.isDesktopPetVisible {
                        store.attachDesktopPetControllerIfNeeded()
                    }
                }
            }
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let store = ImagePetStore.shared {
            store.launchMode = .reopen
            store.activateMainWindow()
        }
        return true
    }
}
