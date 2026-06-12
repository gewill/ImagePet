import Foundation

public actor OutputNameAllocator {
    private var reservations: Set<String> = []
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func reserveOutputURL(
        for inputURL: URL,
        in outputDirectory: URL,
        suffix: String,
        targetExtension: String
    ) -> URL {
        var index = 0

        while true {
            let fileName = Self.outputFileName(for: inputURL, suffix: suffix, targetExtension: targetExtension, duplicateIndex: index)
            let candidate = outputDirectory.appendingPathComponent(fileName, isDirectory: false)
            let key = Self.key(for: candidate)

            if !reservations.contains(key), !fileManager.fileExists(atPath: candidate.path) {
                reservations.insert(key)
                return candidate
            }

            index += 1
        }
    }

    public func reserveOutputURL(for inputURL: URL, in outputDirectory: URL) -> URL {
        var index = 0

        while true {
            let fileName = Self.outputFileName(for: inputURL, duplicateIndex: index)
            let candidate = outputDirectory.appendingPathComponent(fileName, isDirectory: false)
            let key = Self.key(for: candidate)

            if !reservations.contains(key), !fileManager.fileExists(atPath: candidate.path) {
                reservations.insert(key)
                return candidate
            }

            index += 1
        }
    }

    public func release(_ url: URL) {
        reservations.remove(Self.key(for: url))
    }

    public func reset() {
        reservations.removeAll()
    }

    public static func sanitizedSuffix(_ suffix: String) -> String {
        var sanitized = ""
        for scalar in suffix.unicodeScalars where isAllowedSuffixScalar(scalar) {
            sanitized.unicodeScalars.append(scalar)
        }
        return sanitized
    }

    /// `suffix` may be empty. `targetExtension` should not include a leading dot;
    /// this function strips one defensively for callers outside the app UI.
    public static func outputFileName(
        for inputURL: URL,
        suffix: String,
        targetExtension: String,
        duplicateIndex: Int = 0
    ) -> String {
        let originalName = inputURL.deletingPathExtension().lastPathComponent
        let baseName = "\(originalName)\(sanitizedSuffix(suffix))"
        let ext = sanitizedExtension(targetExtension)

        if duplicateIndex == 0 {
            return ext.isEmpty ? baseName : "\(baseName).\(ext)"
        }

        return ext.isEmpty ? "\(baseName)-\(duplicateIndex + 1)" : "\(baseName)-\(duplicateIndex + 1).\(ext)"
    }

    public static func outputFileName(for inputURL: URL, duplicateIndex: Int = 0) -> String {
        let originalName = inputURL.deletingPathExtension().lastPathComponent
        let inputExtension = inputURL.pathExtension.lowercased()
        let baseName: String

        if inputExtension.isEmpty {
            baseName = "\(originalName)_compressed"
        } else {
            baseName = "\(originalName)-\(inputExtension)_compressed"
        }

        if duplicateIndex == 0 {
            return "\(baseName).jpg"
        }

        return "\(baseName)-\(duplicateIndex + 1).jpg"
    }

    private static func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static func sanitizedExtension(_ targetExtension: String) -> String {
        let trimmed = targetExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingDots = trimmed.drop { $0 == "." }
        var sanitized = ""
        for scalar in withoutLeadingDots.lowercased().unicodeScalars where isASCIILetterOrDigit(scalar) {
            sanitized.unicodeScalars.append(scalar)
        }
        return sanitized
    }

    private static func isAllowedSuffixScalar(_ scalar: UnicodeScalar) -> Bool {
        isASCIILetterOrDigit(scalar) || scalar == "_" || scalar == "-"
    }

    private static func isASCIILetterOrDigit(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...90, 97...122:
            return true
        default:
            return false
        }
    }
}
