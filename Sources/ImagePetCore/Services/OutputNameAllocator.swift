import Foundation

public actor OutputNameAllocator {
    private var reservations: Set<String> = []
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
}
