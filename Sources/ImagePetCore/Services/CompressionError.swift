import Foundation

public enum CompressionError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedImageFormat
    case permissionDenied
    case outputFolderUnavailable
    case failedToDecodeImage
    case failedToWriteOutputFile
    case notEnoughDiskSpace
    case skipped
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unsupportedImageFormat:
            return "Unsupported image format"
        case .permissionDenied:
            return "Permission denied"
        case .outputFolderUnavailable:
            return "Output folder unavailable"
        case .failedToDecodeImage:
            return "Failed to decode image"
        case .failedToWriteOutputFile:
            return "Failed to write output file"
        case .notEnoughDiskSpace:
            return "Not enough disk space"
        case .skipped:
            return "Compression skipped (size would increase)"
        case .unknown:
            return "Unknown error"
        }
    }

    public static func map(_ error: Error) -> CompressionError {
        if let compressionError = error as? CompressionError {
            return compressionError
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .permissionDenied
            case NSFileWriteOutOfSpaceError:
                return .notEnoughDiskSpace
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .outputFolderUnavailable
            default:
                break
            }
        }

        return .unknown
    }
}
