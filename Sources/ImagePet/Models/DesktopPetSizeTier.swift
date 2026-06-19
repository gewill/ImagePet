import CoreGraphics
import Foundation

struct DesktopPetSizeMetrics: Equatable {
    static let minPetSize: CGFloat = 64
    static let defaultPetSize: CGFloat = 80
    static let maxPetSize: CGFloat = 256
    static let accessibilityStep: CGFloat = 4

    let petSize: CGFloat

    init(petSize: CGFloat) {
        self.petSize = Self.clamped(petSize)
    }

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, minPetSize), maxPetSize)
    }

    static func migratedPetSize(from legacyTier: String) -> CGFloat? {
        switch legacyTier {
        case "compact":
            return 64
        case "standard":
            return 80
        case "large":
            return 96
        default:
            return nil
        }
    }

    var accessibilityValue: String {
        "\(Int(round(petSize))) px"
    }

    var miniWindow: CGSize {
        CGSize(width: petSize + 16, height: petSize + 16)
    }

    var fullWindow: CGSize {
        CGSize(width: petSize * 1.5 + 96, height: petSize * 1.25 + 96)
    }

    var petArtFrame: CGSize {
        CGSize(width: petSize, height: petSize * 0.875)
    }

    var petFaceFrame: CGSize {
        CGSize(width: petSize + 2, height: petSize * 0.875 + 2)
    }

    var miniPetFrame: CGSize {
        CGSize(width: petSize + 8, height: petSize + 8)
    }

    func windowSize(for mode: DesktopPetViewMode) -> CGSize {
        mode == .mini ? miniWindow : fullWindow
    }
}
