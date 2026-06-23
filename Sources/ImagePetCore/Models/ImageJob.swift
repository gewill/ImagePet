import Foundation

public struct ImageJob: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let inputURL: URL
    public var outputURL: URL?
    public var originalSize: Int64
    public var compressedSize: Int64?
    public var status: JobStatus
    public var errorMessage: String?
    public var designatedOutputDirectory: URL?

    public init(
        id: UUID = UUID(),
        inputURL: URL,
        outputURL: URL? = nil,
        originalSize: Int64,
        compressedSize: Int64? = nil,
        status: JobStatus = .pending,
        errorMessage: String? = nil,
        designatedOutputDirectory: URL? = nil
    ) {
        self.id = id
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.status = status
        self.errorMessage = errorMessage
        self.designatedOutputDirectory = designatedOutputDirectory
    }

    public var fileName: String {
        inputURL.lastPathComponent
    }

    public var savedSize: Int64? {
        guard let compressedSize else { return nil }
        return originalSize - compressedSize
    }

    public var savedRatio: Double? {
        guard originalSize > 0, let savedSize else { return nil }
        return Double(savedSize) / Double(originalSize)
    }
}

public enum JobStatus: Equatable, Sendable {
    case pending
    case processing
    case done
    case failed
    case skipped
    case canceled
}

public enum PetState: Equatable, Sendable {
    case idle
    case eating
    case happy
    case error
}
