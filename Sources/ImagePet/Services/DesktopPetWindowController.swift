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
    private var isAppTerminating = false

    init(store: ImagePetStore) {
        self.store = store
        super.init()

        store.$petViewMode
            .sink { [weak self] mode in
                self?.updateWindowSize(for: mode)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func appWillTerminate(_ notification: Notification) {
        isAppTerminating = true
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
        guard !isAppTerminating else { return }
        store.hideDesktopPet()
    }

    private func show() {
        let window = window ?? makeWindow()
        self.window = window
        updateWindowSize(for: store.petViewMode)
        window.orderFrontRegardless()
    }

    private func hide() {
        window?.orderOut(nil)
    }

    private func updateWindowSize(for mode: DesktopPetViewMode) {
        guard let window = self.window else { return }
        let newSize = mode == .mini ? Self.miniSize : Self.fullSize
        let currentFrame = window.frame
        let newOrigin: NSPoint
        if currentFrame.size == newSize {
            newOrigin = currentFrame.origin
        } else {
            let currentCenter = NSPoint(x: currentFrame.midX, y: currentFrame.midY)
            newOrigin = NSPoint(
                x: currentCenter.x - newSize.width / 2,
                y: currentCenter.y - newSize.height / 2
            )
        }

        let newFrame = constrainedFrame(NSRect(origin: newOrigin, size: newSize))
        guard window.frame != newFrame else { return }

        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        window.setFrame(newFrame, display: true, animate: shouldAnimate)
    }

    private func makeWindow() -> NSWindow {
        if ProcessInfo.processInfo.arguments.contains("-ImagePetResetWindowFrame") {
            UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(Self.frameAutosaveName)")
        }

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
            window.setFrame(constrainedFrame(NSRect(origin: window.frame.origin, size: size)), display: false)
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
        } else {
            window.setFrame(constrainedFrame(window.frame), display: false)
        }
    }

    private func defaultFrame(for size: NSSize) -> NSRect {
        constrainedFrame(NSRect(origin: defaultOrigin(for: size), size: size))
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let expandedWidth = max(size.width, Self.fullSize.width)
        let horizontalInset = 28 + (expandedWidth - size.width) / 2
        return NSPoint(
            x: visibleFrame.maxX - size.width - horizontalInset,
            y: visibleFrame.minY + 92
        )
    }

    private func constrainedFrame(_ frame: NSRect) -> NSRect {
        guard let screen = screen(for: frame) else { return frame }

        let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - width
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - height
        let origin = NSPoint(
            x: min(max(frame.origin.x, minX), maxX),
            y: min(max(frame.origin.y, minY), maxY)
        )

        return NSRect(origin: origin, size: NSSize(width: width, height: height))
    }

    private func screen(for frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        if let containingScreen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return containingScreen
        }

        return NSScreen.screens
            .map { screen in (screen, frame.intersection(screen.visibleFrame).width * frame.intersection(screen.visibleFrame).height) }
            .max { $0.1 < $1.1 }?
            .0 ?? NSScreen.main
    }
}

private final class DesktopPetWindow: NSWindow {
    override var canBecomeKey: Bool {
        false
    }
}
