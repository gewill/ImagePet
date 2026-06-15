import Foundation
import UniformTypeIdentifiers

/// The output format for compressed images.
public enum OutputFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case jpeg
    case png
    case heic
    case webp
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .webp: return "WebP"
        }
    }
    
    public func targetUTType(for inputURL: URL) -> UTType {
        switch self {
        case .original:
            return UTType(filenameExtension: inputURL.pathExtension) ?? .jpeg
        case .jpeg:
            return .jpeg
        case .png:
            return .png
        case .heic:
            return .heic
        case .webp:
            return .imagePetWebP
        }
    }

    public func targetExtension(for inputURL: URL) -> String {
        switch self {
        case .original:
            return SupportedImageFormat.format(for: inputURL)?.preferredFilenameExtension
                ?? inputURL.pathExtension.lowercased()
        case .jpeg:
            return "jpg"
        case .png:
            return "png"
        case .heic:
            return "heic"
        case .webp:
            return "webp"
        }
    }
}

public extension UTType {
    static let imagePetWebP = UTType(filenameExtension: "webp") ?? UTType(exportedAs: "org.webmproject.webp")
}

/// The mode for where the output file should be written.
public enum SaveLocationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case designated
    case originalFolder
    case overwrite
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .designated: return "Designated Folder"
        case .originalFolder: return "Original Folder"
        case .overwrite: return "Overwrite Original"
        }
    }
}

/// The limit for the maximum dimension on the image's long edge.
public enum MaxDimensionLimit: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case p1024 = "1024"
    case p1920 = "1920"
    case p2048 = "2048"
    case p3840 = "3840"
    
    public var id: String { rawValue }
    
    public var intValue: Int? {
        switch self {
        case .none: return nil
        case .p1024: return 1024
        case .p1920: return 1920
        case .p2048: return 2048
        case .p3840: return 3840
        }
    }
    
    public var displayName: String {
        switch self {
        case .none: return "No Resize"
        default: return "\(rawValue)px"
        }
    }
}

public enum OverwritePolicy: String, Codable, Sendable {
    case replaceOriginalKeepingFormat
}

/// Encoding and transform options passed to the compressor.
public struct CompressionOptions: Sendable, Equatable, Codable {
    public let lossyQuality: CompressionQuality?
    public let format: OutputFormat
    public let maxDimension: MaxDimensionLimit
    public let stripMetadata: Bool
    
    public init(
        lossyQuality: CompressionQuality? = .preset(.balanced),
        format: OutputFormat = .original,
        maxDimension: MaxDimensionLimit = .none,
        stripMetadata: Bool = true
    ) {
        self.format = format
        self.lossyQuality = format == .png ? nil : lossyQuality
        self.maxDimension = maxDimension
        self.stripMetadata = stripMetadata
    }
}

/// Filesystem save behavior kept outside encoder options.
public struct SaveOptions: Sendable, Equatable, Codable {
    public let locationMode: SaveLocationMode
    public let suffix: String
    public let overwritePolicy: OverwritePolicy

    public init(
        locationMode: SaveLocationMode = .designated,
        suffix: String = "_compressed",
        overwritePolicy: OverwritePolicy = .replaceOriginalKeepingFormat
    ) {
        self.locationMode = locationMode
        self.suffix = suffix
        self.overwritePolicy = overwritePolicy
    }
}
