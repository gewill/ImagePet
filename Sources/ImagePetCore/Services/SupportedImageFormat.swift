import Foundation

public enum SupportedImageFormat {
    public static let supportedExtensions: Set<String> = [
        "jpg",
        "jpeg",
        "png",
        "heic"
    ]

    public static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
