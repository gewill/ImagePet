import Foundation
import ImagePetCore

enum BackgroundCompressionSource: String, Codable, Equatable, Sendable {
    case manual
    case folderWatching
    case finderService
    case shortcuts

    var displayName: String {
        switch self {
        case .manual:
            return "ImagePet"
        case .folderWatching:
            return "Folder Watching"
        case .finderService:
            return "Finder Quick Action"
        case .shortcuts:
            return "Shortcuts"
        }
    }
}

struct BackgroundCompressionSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: BackgroundCompressionSource
    let successfulCount: Int
    let failedCount: Int
    let skippedCount: Int
    let totalInputBytes: Int64
    let totalOutputBytes: Int64
    let outputDirectory: URL?
    let representativeOutputURL: URL?
    let requiresUserAction: Bool
    let primaryErrorMessage: String?
    let completedAt: Date

    init(
        id: UUID = UUID(),
        source: BackgroundCompressionSource,
        successfulCount: Int,
        failedCount: Int,
        skippedCount: Int,
        totalInputBytes: Int64,
        totalOutputBytes: Int64,
        outputDirectory: URL?,
        representativeOutputURL: URL?,
        requiresUserAction: Bool,
        primaryErrorMessage: String?,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.successfulCount = successfulCount
        self.failedCount = failedCount
        self.skippedCount = skippedCount
        self.totalInputBytes = totalInputBytes
        self.totalOutputBytes = totalOutputBytes
        self.outputDirectory = outputDirectory
        self.representativeOutputURL = representativeOutputURL
        self.requiresUserAction = requiresUserAction
        self.primaryErrorMessage = primaryErrorMessage
        self.completedAt = completedAt
    }

    init(source: BackgroundCompressionSource, jobs: [ImageJob], completedAt: Date = Date()) {
        let successfulJobs = jobs.filter { $0.status == .done }
        let failedJobs = jobs.filter { $0.status == .failed }
        let skippedJobs = jobs.filter { $0.status == .skipped }
        let firstOutputURL = successfulJobs.compactMap(\.outputURL).first
        let outputDirectories = Set(successfulJobs.compactMap { $0.outputURL?.deletingLastPathComponent() })
        let outputDirectory = outputDirectories.count == 1 ? outputDirectories.first : nil
        let primaryErrorMessage = failedJobs.compactMap(\.errorMessage).first

        self.init(
            source: source,
            successfulCount: successfulJobs.count,
            failedCount: failedJobs.count,
            skippedCount: skippedJobs.count,
            totalInputBytes: successfulJobs.reduce(Int64(0)) { $0 + $1.originalSize },
            totalOutputBytes: successfulJobs.reduce(Int64(0)) { $0 + ($1.compressedSize ?? 0) },
            outputDirectory: outputDirectory,
            representativeOutputURL: firstOutputURL,
            requiresUserAction: !failedJobs.isEmpty,
            primaryErrorMessage: primaryErrorMessage,
            completedAt: completedAt
        )
    }

    var totalCount: Int {
        successfulCount + failedCount + skippedCount
    }

    var savedBytes: Int64 {
        max(0, totalInputBytes - totalOutputBytes)
    }

    var hasSuccesses: Bool {
        successfulCount > 0
    }

    var hasFailures: Bool {
        failedCount > 0
    }

    var statusText: String {
        if hasSuccesses && !hasFailures {
            return "Completed"
        }
        if hasSuccesses && hasFailures {
            return "Needs review"
        }
        if hasFailures {
            return "Failed"
        }
        if skippedCount > 0 {
            return "Skipped"
        }
        return "No files processed"
    }
}
