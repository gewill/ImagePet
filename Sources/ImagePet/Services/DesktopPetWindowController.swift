import AppKit
import SwiftUI

@MainActor
final class DesktopPetWindowController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "ImagePetDesktopPetWindow"
    private static let windowSize = NSSize(width: 192, height: 176)

    private let store: ImagePetStore
    private var window: NSWindow?

    init(store: ImagePetStore) {
        self.store = store
        super.init()
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            show()
        } else {
            hide()
        }
    }

    func closeWindow() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        store.hideDesktopPet()
    }

    private func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.orderFrontRegardless()
    }

    private func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let size = Self.windowSize
        let window = DesktopPetWindow(
            contentRect: NSRect(origin: defaultOrigin(for: size), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("DesktopPetWindow")
        window.contentView = NSHostingView(rootView: DesktopPetView(store: store))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.delegate = self

        if window.setFrameUsingName(Self.frameAutosaveName) {
            window.setFrame(NSRect(origin: window.frame.origin, size: size), display: false)
            ensureFrameIsVisible(window, fallbackSize: size)
        } else {
            window.setFrame(defaultFrame(for: size), display: false)
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)

        return window
    }

    private func ensureFrameIsVisible(_ window: NSWindow, fallbackSize: NSSize) {
        let isVisibleOnAnyScreen = NSScreen.screens.contains { screen in
            window.frame.intersects(screen.visibleFrame)
        }

        if !isVisibleOnAnyScreen {
            window.setFrame(defaultFrame(for: fallbackSize), display: false)
        }
    }

    private func defaultFrame(for size: NSSize) -> NSRect {
        NSRect(origin: defaultOrigin(for: size), size: size)
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.minY + 92
        )
    }
}

private final class DesktopPetWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }
}
