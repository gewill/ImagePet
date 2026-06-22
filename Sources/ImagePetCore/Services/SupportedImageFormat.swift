import Foundation

public enum SupportedImageFormat: String, CaseIterable, Codable, Sendable, Hashable {
    case jpeg
    case png
    case heic
    case webp

    public var preferredFilenameExtension: String {
        switch self {
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

    public var filenameExtensions: Set<String> {
        switch self {
        case .jpeg:
            return ["jpg", "jpeg"]
        case .png:
            return ["png"]
        case .heic:
            return ["heic"]
        case .webp:
            return ["webp"]
        }
    }

    public static func format(for url: URL) -> SupportedImageFormat? {
        let ext = url.pathExtension.lowercased()
        return allCases.first { $0.filenameExtensions.contains(ext) }
    }

    public static var supportedExtensions: Set<String> {
        supportedExtensions(capabilities: .current)
    }

    public static func supportedExtensions(capabilities: EncoderCapabilities) -> Set<String> {
        capabilities.readableFormats.reduce(into: Set<String>()) { result, format in
            result.formUnion(format.filenameExtensions)
        }
    }

    public static func isSupported(_ url: URL) -> Bool {
        isSupported(url, capabilities: .current)
    }

    public static func isSupported(_ url: URL, capabilities: EncoderCapabilities) -> Bool {
        guard let format = format(for: url) else {
            return false
        }
        return capabilities.readableFormats.contains(format)
    }
}
