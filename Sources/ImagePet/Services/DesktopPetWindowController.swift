import AppKit
import SwiftUI

@MainActor
final class DesktopPetWindowController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "ImagePetDesktopPetWindow"

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
        let size = NSSize(width: 168, height: 156)
        let window = DesktopPetWindow(
            contentRect: NSRect(origin: defaultOrigin(for: size), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: DesktopPetView(store: store))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.delegate = self

        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.setFrame(NSRect(origin: defaultOrigin(for: size), size: size), display: false)
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)

        return window
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
