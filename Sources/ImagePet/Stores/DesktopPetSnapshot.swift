import Foundation

enum DesktopPetDisplayState: Equatable {
    case idle
    case needsSetup
    case eating
    case done
    case issues
    case confirm
    case permission
}

enum DesktopPetAction: Equatable {
    case openMainApp
    case hidePet
    case addImages
    case revealOutput
    case retryFailed
    case compressMore
    case expand
    case collapse
}

enum DesktopPetViewMode: String, Codable, Equatable {
    case mini
    case full
}

struct DesktopPetSnapshot: Equatable {
    let state: DesktopPetDisplayState
    let title: String
    let detail: String
    let primaryAction: DesktopPetAction?
    let secondaryActions: [DesktopPetAction]
    let canAcceptDrop: Bool
}
