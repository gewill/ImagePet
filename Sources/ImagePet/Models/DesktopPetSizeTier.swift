import CoreGraphics
import Foundation

enum DesktopPetSizeTier: String, CaseIterable, Codable, Identifiable {
    case compact
    case standard
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .large:
            return "Large"
        }
    }

    var detail: String {
        switch self {
        case .compact:
            return "64 px pet face"
        case .standard:
            return "80 px pet face"
        case .large:
            return "96 px pet face"
        }
    }

    var miniWindow: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 80, height: 80)
        case .standard:
            return CGSize(width: 96, height: 96)
        case .large:
            return CGSize(width: 112, height: 112)
        }
    }

    var fullWindow: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 192, height: 176)
        case .standard:
            return CGSize(width: 216, height: 196)
        case .large:
            return CGSize(width: 240, height: 216)
        }
    }

    var petArtFrame: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 64, height: 56)
        case .standard:
            return CGSize(width: 80, height: 70)
        case .large:
            return CGSize(width: 96, height: 84)
        }
    }

    var petFaceFrame: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 66, height: 58)
        case .standard:
            return CGSize(width: 82, height: 72)
        case .large:
            return CGSize(width: 98, height: 86)
        }
    }

    var miniPetFrame: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 72, height: 72)
        case .standard:
            return CGSize(width: 88, height: 88)
        case .large:
            return CGSize(width: 104, height: 104)
        }
    }

    func windowSize(for mode: DesktopPetViewMode) -> CGSize {
        mode == .mini ? miniWindow : fullWindow
    }
}
