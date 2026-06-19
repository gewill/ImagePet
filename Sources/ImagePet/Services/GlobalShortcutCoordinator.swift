import Foundation
import KeyboardShortcuts

struct ImagePetShortcutAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    let name: KeyboardShortcuts.Name

    static let all: [ImagePetShortcutAction] = [
        ImagePetShortcutAction(
            id: "showMainWindow",
            title: "Show Main Window",
            detail: "Bring ImagePet forward without changing the current queue.",
            name: .showMainWindow
        ),
        ImagePetShortcutAction(
            id: "toggleDesktopPet",
            title: "Show / Hide Desktop Pet",
            detail: "Show or hide the desktop pet from anywhere on your Mac.",
            name: .toggleDesktopPet
        ),
        ImagePetShortcutAction(
            id: "togglePetMode",
            title: "Toggle Pet Mini / Full",
            detail: "Expand or collapse the desktop pet when it is visible.",
            name: .togglePetMode
        )
    ]
}

extension KeyboardShortcuts.Name {
    static let showMainWindow = Self("showMainWindow")
    static let toggleDesktopPet = Self("toggleDesktopPet")
    static let togglePetMode = Self("togglePetMode")
}

@MainActor
final class GlobalShortcutCoordinator: ObservableObject {
    private weak var store: ImagePetStore?
    private var didRegisterHandlers = false

    func bind(to store: ImagePetStore) {
        self.store = store

        guard !didRegisterHandlers else {
            return
        }

        guard ProcessInfo.processInfo.environment["IS_UI_TESTING"] != "1" else {
            return
        }

        didRegisterHandlers = true

        KeyboardShortcuts.onKeyUp(for: .showMainWindow) { [weak self] in
            Task { @MainActor in
                self?.store?.activateMainWindow()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .toggleDesktopPet) { [weak self] in
            Task { @MainActor in
                self?.store?.toggleDesktopPet()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .togglePetMode) { [weak self] in
            Task { @MainActor in
                self?.store?.toggleDesktopPetMode()
            }
        }
    }
}
