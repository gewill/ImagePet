import Foundation

public enum CompressionPreset: String, CaseIterable, Identifiable, Codable, Sendable {
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

public enum CompressionQuality: Equatable, Codable, Sendable {
    case preset(CompressionPreset)
    case custom(Int)

    public var value: Double {
        switch self {
        case .preset(let preset):
            return preset.quality
        case .custom(let quality):
            let clamped = min(95, max(30, quality))
            return Double(clamped) / 100.0
        }
    }

    public var displayName: String {
        switch self {
        case .preset(let preset):
            return preset.displayName
        case .custom(let quality):
            return "Quality \(min(95, max(30, quality)))"
        }
    }
}

public enum CompressionQualityMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case high
    case balanced
    case small
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .high:
            return CompressionPreset.high.displayName
        case .balanced:
            return CompressionPreset.balanced.displayName
        case .small:
            return CompressionPreset.small.displayName
        case .custom:
            return "Custom"
        }
    }

    public var preset: CompressionPreset? {
        switch self {
        case .high:
            return .high
        case .balanced:
            return .balanced
        case .small:
            return .small
        case .custom:
            return nil
        }
    }

    public init(preset: CompressionPreset) {
        switch preset {
        case .high:
            self = .high
        case .balanced:
            self = .balanced
        case .small:
            self = .small
        }
    }

    public func compressionQuality(customQuality: Int) -> CompressionQuality {
        if let preset {
            return .preset(preset)
        }
        return .custom(customQuality)
    }
}
