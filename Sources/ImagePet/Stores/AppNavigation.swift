import Foundation

enum AppMainTab: String, CaseIterable, Identifiable {
    case compress
    case settings

    var id: String { rawValue }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case folderWatching
    case notifications
    case desktopPet
    case keyboardShortcuts
    case helpAbout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .folderWatching:
            return "Folder Watching"
        case .notifications:
            return "Notifications"
        case .desktopPet:
            return "Desktop Pet"
        case .keyboardShortcuts:
            return "Keyboard Shortcuts"
        case .helpAbout:
            return "Help & About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .folderWatching:
            return "folder.badge.gearshape"
        case .notifications:
            return "bell.badge"
        case .desktopPet:
            return "pawprint"
        case .keyboardShortcuts:
            return "keyboard"
        case .helpAbout:
            return "questionmark.circle"
        }
    }
}
