import Foundation

public enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case high
    case balanced
    case small

    public var id: String { rawValue }

    public var quality: Double {
        switch self {
        case .high:
            return 0.9
        case .balanced:
            return 0.8
        case .small:
            return 0.65
        }
    }

    public var displayName: String {
        switch self {
        case .high:
            return "High"
        case .balanced:
            return "Balanced"
        case .small:
            return "Small"
        }
    }
}
