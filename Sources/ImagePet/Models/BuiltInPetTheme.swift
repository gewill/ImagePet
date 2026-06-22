import Foundation

struct BuiltInPetTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let defaultFPS: Int

    private static let dog = BuiltInPetTheme(
        id: "Dog",
        displayName: "Dog",
        description: "A friendly all-round puppy with balanced motion.",
        defaultFPS: 10
    )

    private static let pufferfish = BuiltInPetTheme(
        id: "Pufferfish",
        displayName: "Pufferfish",
        description: "A soft floating puffer with gentler pacing.",
        defaultFPS: 8
    )

    private static let squirrel = BuiltInPetTheme(
        id: "Squirrel",
        displayName: "Squirrel",
        description: "A quick-tailed squirrel with slightly snappier motion.",
        defaultFPS: 12
    )

    private static let hamster = BuiltInPetTheme(
        id: "Hamster",
        displayName: "Hamster",
        description: "A round hamster that feels cozy and compact.",
        defaultFPS: 9
    )

    private static let cat = BuiltInPetTheme(
        id: "Cat",
        displayName: "Cat",
        description: "A warm orange cat with easy idle confidence.",
        defaultFPS: 10
    )

    private static let rabbit = BuiltInPetTheme(
        id: "Rabbit",
        displayName: "Rabbit",
        description: "A long-eared rabbit with light, springy movement.",
        defaultFPS: 11
    )

    private static let fallbackThemes: [BuiltInPetTheme] = [
        dog,
        pufferfish,
        squirrel,
        hamster,
        cat,
        rabbit
    ]

    static let all: [BuiltInPetTheme] = fallbackThemes.map { fallbackTheme in
        loadManifestTheme(for: fallbackTheme.id) ?? fallbackTheme
    }

    static let fallback = all.first(where: { $0.id == dog.id }) ?? dog

    static func theme(named id: String) -> BuiltInPetTheme? {
        all.first { $0.id == id }
    }

    static func resolvedTheme(named id: String) -> BuiltInPetTheme {
        theme(named: id) ?? fallback
    }

    private static func loadManifestTheme(for themeID: String) -> BuiltInPetTheme? {
        guard let manifestURL = manifestURL(for: themeID),
              let data = try? Data(contentsOf: manifestURL) else {
            return nil
        }

        return validatedManifestTheme(for: themeID, data: data)
    }

    private static func validatedManifestTheme(for themeID: String, data: Data) -> BuiltInPetTheme? {
        guard let manifest = try? JSONDecoder().decode(ThemeManifest.self, from: data),
              manifest.schemaVersion == 1,
              manifest.themeId == themeID,
              !manifest.displayName.isEmpty,
              !manifest.description.isEmpty,
              (8...12).contains(manifest.defaultFPS),
              manifest.assetFormat == "png-sequence",
              manifest.cellSize.width == 256,
              manifest.cellSize.height == 256 else {
            return nil
        }

        return BuiltInPetTheme(
            id: manifest.themeId,
            displayName: manifest.displayName,
            description: manifest.description,
            defaultFPS: manifest.defaultFPS
        )
    }

    private static func manifestURL(for themeID: String) -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "theme", withExtension: "json", subdirectory: themeID) {
            return url
        }
        if let url = Bundle.module.url(forResource: "theme", withExtension: "json", subdirectory: "Resources/\(themeID)") {
            return url
        }
        #endif

        if let url = Bundle.main.url(forResource: "theme", withExtension: "json", subdirectory: themeID) {
            return url
        }
        if let url = Bundle.main.url(forResource: "theme", withExtension: "json", subdirectory: "Resources/\(themeID)") {
            return url
        }

        if let resourceURL = Bundle.main.resourceURL {
            let directManifest = resourceURL
                .appendingPathComponent(themeID)
                .appendingPathComponent("theme.json")
            if FileManager.default.fileExists(atPath: directManifest.path) {
                return directManifest
            }

            let nestedManifest = resourceURL
                .appendingPathComponent("Resources")
                .appendingPathComponent(themeID)
                .appendingPathComponent("theme.json")
            if FileManager.default.fileExists(atPath: nestedManifest.path) {
                return nestedManifest
            }

            let xcodeBundleURL = resourceURL.appendingPathComponent("ImagePet_ImagePet.bundle")
            if let bundle = Bundle(url: xcodeBundleURL),
               let url = bundle.url(forResource: "theme", withExtension: "json", subdirectory: themeID) {
                return url
            }
        }

        return nil
    }
}

private struct ThemeManifest: Decodable {
    let schemaVersion: Int
    let themeId: String
    let displayName: String
    let description: String
    let defaultFPS: Int
    let cellSize: ThemeCellSize
    let assetFormat: String
}

private struct ThemeCellSize: Decodable {
    let width: Int
    let height: Int
}
