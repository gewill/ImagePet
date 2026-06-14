import AppKit
import SwiftUI
import Combine

@MainActor
final class DesktopPetWindowController: NSObject, NSWindowDelegate {
    private static let frameAutosaveName = "ImagePetDesktopPetWindow"
    private static let miniSize = NSSize(width: 80, height: 80)
    private static let fullSize = NSSize(width: 192, height: 176)

    private let store: ImagePetStore
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(store: ImagePetStore) {
        self.store = store
        super.init()
        
        store.$petViewMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateWindowSize(for: mode)
            }
            .store(in: &cancellables)
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

    private func updateWindowSize(for mode: DesktopPetViewMode) {
        guard let window = self.window else { return }
        let newSize = mode == .mini ? Self.miniSize : Self.fullSize
        guard window.frame.size != newSize else { return }
        
        let currentFrame = window.frame
        let currentCenter = NSPoint(x: currentFrame.midX, y: currentFrame.midY)
        let newOrigin = NSPoint(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2
        )
        
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        
        window.setFrame(newFrame, display: true, animate: shouldAnimate)
    }

    private func makeWindow() -> NSWindow {
        let size = store.petViewMode == .mini ? Self.miniSize : Self.fullSize
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
        false
    }
}
