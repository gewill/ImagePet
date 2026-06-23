import Foundation
import CoreGraphics

public enum ThumbnailSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large
    
    public var id: String { rawValue }
    
    public var size: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 48
        case .large: return 72
        }
    }
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}
