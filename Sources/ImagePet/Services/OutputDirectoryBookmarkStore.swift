import Foundation
import ImagePetCore

@MainActor
final class OutputDirectoryBookmarkStore {
    private let defaults: UserDefaults
    private let key = "ImagePet.outputDirectoryBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func restore() throws -> URL? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard !isStale else {
            clear()
            throw CompressionError.outputFolderUnavailable
        }

        return url
    }

    func save(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmark, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
