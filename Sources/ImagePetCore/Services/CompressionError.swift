import Foundation

public enum CompressionError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedImageFormat
    case permissionDenied
    case outputFolderUnavailable
    case failedToDecodeImage
    case failedToWriteOutputFile
    case notEnoughDiskSpace
    case skipped
    case webPOutputUnavailable
    case advancedJPEGUnavailable
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
            return "Skipped: output would be larger than source"
        case .webPOutputUnavailable:
            return "Skipped: WebP output is unavailable on this Mac"
        case .advancedJPEGUnavailable:
            return "Skipped: Advanced JPEG is unavailable on this Mac"
        case .unknown:
            return "Unknown error"
        }
    }

    public var isSkippedResult: Bool {
        self == .skipped || self == .webPOutputUnavailable || self == .advancedJPEGUnavailable
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
