import Foundation

public struct CompressionResult: Equatable, Sendable {
    public let inputURL: URL
    public let outputURL: URL
    public let originalSize: Int64
    public let compressedSize: Int64

    public init(
        inputURL: URL,
        outputURL: URL,
        originalSize: Int64,
        compressedSize: Int64
    ) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.originalSize = originalSize
        self.compressedSize = compressedSize
    }
}
