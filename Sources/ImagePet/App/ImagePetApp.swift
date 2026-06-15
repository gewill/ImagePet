import AppKit
import SwiftUI

@main
struct ImagePetApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ImagePetStore()
    @StateObject private var shortcutCoordinator = GlobalShortcutCoordinator()

    var body: some Scene {
        WindowGroup("ImagePet") {
            ContentView(store: store)
                .onAppear {
                    shortcutCoordinator.bind(to: store)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Images...") {
                    store.chooseInputImages()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Choose Output Folder...") {
                    store.chooseOutputDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Clear List") {
                    store.clearList()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(store.isProcessing)

                Button("Retry Failed") {
                    store.retryFailed()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isProcessing || !store.hasFailedJobs)
            }

            CommandGroup(after: .toolbar) {
                Button("Show Main Window") {
                    store.activateMainWindow()
                }
                .keyboardShortcut("1", modifiers: [.command])

                Divider()

                Button(store.isDesktopPetVisible ? "Hide Desktop Pet" : "Show Desktop Pet") {
                    store.toggleDesktopPet()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!store.isDesktopPetEnabled)

                Button("Toggle Pet Mini / Full") {
                    store.toggleDesktopPetMode()
                }
                .disabled(!store.isDesktopPetEnabled)
            }

            CommandMenu("Settings") {
                Button("Desktop Pet Settings...") {
                    store.showSettings(.desktopPet)
                }

                Button("Keyboard Shortcuts...") {
                    store.showSettings(.keyboardShortcuts)
                }

                Button("Notifications...") {
                    store.showSettings(.notifications)
                }

                Button("Help & About...") {
                    store.showSettings(.helpAbout)
                }
            }

            CommandGroup(replacing: .help) {
                Button("ImagePet Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])

                Button("Keyboard Shortcuts...") {
                    store.showSettings(.keyboardShortcuts)
                }
            }
        }

        Window("ImagePet", id: "main") {
            ContentView(store: store)
                .onAppear {
                    shortcutCoordinator.bind(to: store)
                }
        }

        Window("ImagePet Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 820, height: 560)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowUpdateObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self

        if let store = ImagePetStore.shared {
            let isUITesting = ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1"
            if store.launchMode == .loginItem {
                windowUpdateObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didUpdateNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        for window in NSApp.windows {
                            let isMainWindow = window.title == "ImagePet" || window.identifier?.rawValue == "main"
                            if isMainWindow && store.launchMode == .loginItem && !store.hasReopened {
                                window.orderOut(nil)
                            }
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
                    DispatchQueue.main.async {
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

    @objc func handleServices(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let items = pboard.pasteboardItems else { return }

        var urls: [URL] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                urls.append(url)
            }
        }

        guard !urls.isEmpty else { return }

        Task { @MainActor in
            if let store = ImagePetStore.shared {
                store.addServiceURLs(urls)

                // Show window if intervention is needed
                if store.outputDirectory == nil && store.saveLocationMode == .designated {
                    store.activateMainWindow()
                } else if store.saveLocationMode == .overwrite && !store.didConfirmOverwrite {
                    store.activateMainWindow()
                }
            }
        }
    }
}
