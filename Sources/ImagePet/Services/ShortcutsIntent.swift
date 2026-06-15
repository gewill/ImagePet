import AppIntents
import Foundation
import ImagePetCore

@available(macOS 13.0, *)
enum ShortcutCompressionPreset: String, AppEnum {
    case small, balanced, high

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Compression Preset")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .small: "Small (Lowest Quality)",
        .balanced: "Balanced",
        .high: "High (Best Quality)"
    ]

    var corePreset: CompressionPreset {
        switch self {
        case .small: return .small
        case .balanced: return .balanced
        case .high: return .high
        }
    }
}

@available(macOS 13.0, *)
enum ShortcutOutputFormat: String, AppEnum {
    case original, jpeg, webp, heic, png

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Output Format")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .original: "Original",
        .jpeg: "JPEG",
        .webp: "WebP",
        .heic: "HEIC",
        .png: "PNG"
    ]

    var coreFormat: OutputFormat {
        switch self {
        case .original: return .original
        case .jpeg: return .jpeg
        case .webp: return .webp
        case .heic: return .heic
        case .png: return .png
        }
    }
}

@available(macOS 13.0, *)
enum ShortcutMaxDimension: String, AppEnum {
    case none, p1024, p1920, p2048, p3840

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Max Dimension")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .none: "No Resize",
        .p1024: "1024px",
        .p1920: "1920px",
        .p2048: "2048px",
        .p3840: "3840px"
    ]

    var coreLimit: MaxDimensionLimit {
        switch self {
        case .none: return .none
        case .p1024: return .p1024
        case .p1920: return .p1920
        case .p2048: return .p2048
        case .p3840: return .p3840
        }
    }
}

@available(macOS 13.0, *)
struct CompressImagesIntent: AppIntent {
    static let title: LocalizedStringResource = "Compress Images with ImagePet"
    static let description: IntentDescription = .init("Compresses image files (JPG, PNG, HEIC) to a specific output format using ImagePet.")

    @Parameter(title: "Images")
    var images: [IntentFile]

    @Parameter(title: "Preset", default: .balanced)
    var preset: ShortcutCompressionPreset

    @Parameter(title: "Format", default: .original)
    var format: ShortcutOutputFormat

    @Parameter(title: "Max Edge", default: ShortcutMaxDimension.none)
    var maxDimension: ShortcutMaxDimension

    @Parameter(title: "Keep Metadata", default: false)
    var keepMetadata: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let compressor = ImageCompressor(capabilities: .current)
        var results: [IntentFile] = []

        let qualityMode = CompressionQualityMode(preset: preset.corePreset)
        let options = CompressionOptions(
            lossyQuality: format.coreFormat == .png ? nil : qualityMode.compressionQuality(customQuality: 80),
            format: format.coreFormat,
            jpegEncodingMode: .standard,
            maxDimension: maxDimension.coreLimit,
            stripMetadata: !keepMetadata
        )

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ImagePetShortcuts_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

        for file in images {
            var needsCleanup = false
            let inputURL: URL

            if let fileURL = file.fileURL {
                inputURL = fileURL
            } else {
                inputURL = tempDir.appendingPathComponent(file.filename)
                try file.data.write(to: inputURL)
                needsCleanup = true
            }

            let hasAccess = inputURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    inputURL.stopAccessingSecurityScopedResource()
                }
                if needsCleanup {
                    try? FileManager.default.removeItem(at: inputURL)
                }
            }

            do {
                let result = try await compressor.compress(
                    inputURL: inputURL,
                    outputDirectory: tempDir,
                    compressionOptions: options,
                    saveOptions: SaveOptions(locationMode: .designated, suffix: "_compressed")
                )
                let intentFile = IntentFile(fileURL: result.outputURL)
                results.append(intentFile)
            } catch {
                print("CompressImagesIntent: failed to compress \(inputURL.lastPathComponent): \(error)")
            }
        }

        let successfulCount = results.count
        let failedCount = images.count - successfulCount

        let summary = CompressionBatchSummary(
            source: .shortcuts,
            successfulCount: successfulCount,
            failedCount: failedCount,
            skippedCount: 0,
            totalInputBytes: 0,
            totalOutputBytes: 0,
            outputDirectory: nil,
            representativeOutputURL: results.first?.fileURL,
            requiresUserAction: failedCount > 0,
            primaryErrorMessage: failedCount > 0 ? "Some files failed to compress." : nil
        )

        await MainActor.run {
            let notificationManager = LocalNotificationManager()
            notificationManager.handleCompletedSummary(summary, appIsActive: false)
        }

        return .result(value: results)
    }
}

@available(macOS 13.0, *)
struct ImagePetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompressImagesIntent(),
            phrases: [
                "Compress \(.applicationName) images",
                "Use \(.applicationName) to compress images"
            ],
            shortTitle: "Compress Images",
            systemImageName: "photo.badge.arrow.down"
        )
    }
}
