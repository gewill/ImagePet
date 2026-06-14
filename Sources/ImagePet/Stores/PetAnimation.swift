import Foundation

enum PetInteractionState: String, Codable, Equatable {
    case none
    case hover
    case dragHover
}

enum PetAnimation: String, CaseIterable, Codable, Equatable {
    case idle
    case dragHover
    case eating
    case done
    case issues
    // Idle variants and other interactions
    case stretch
    case yawn
    case petting
    case sleep
}
