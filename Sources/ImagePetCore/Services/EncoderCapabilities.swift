import Foundation

public struct EncoderCapabilities: Sendable, Equatable {
    public let readableFormats: Set<SupportedImageFormat>
    public let writableFormats: Set<OutputFormat>
    public let supportsCustomQuality: Bool
    public let alphaCapableFormats: Set<OutputFormat>
    public let supportsBitstreamInspection: Bool
    public let jpegEncodingModes: Set<JPEGEncodingMode>

    public init(
        readableFormats: Set<SupportedImageFormat>,
        writableFormats: Set<OutputFormat>,
        supportsCustomQuality: Bool,
        alphaCapableFormats: Set<OutputFormat>,
        supportsBitstreamInspection: Bool,
        jpegEncodingModes: Set<JPEGEncodingMode> = [.standard]
    ) {
        self.readableFormats = readableFormats
        self.writableFormats = writableFormats
        self.supportsCustomQuality = supportsCustomQuality
        self.alphaCapableFormats = alphaCapableFormats
        self.supportsBitstreamInspection = supportsBitstreamInspection
        self.jpegEncodingModes = jpegEncodingModes
    }

    public static let nativeOnly = EncoderCapabilities(
        readableFormats: [.jpeg, .png, .heic],
        writableFormats: [.original, .jpeg, .png, .heic],
        supportsCustomQuality: true,
        alphaCapableFormats: [.png, .heic],
        supportsBitstreamInspection: false,
        jpegEncodingModes: [.standard]
    )
}
