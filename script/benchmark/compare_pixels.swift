import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

// Offline oracle for normalized, displayed pixels. Premultiplied RGBA intentionally
// ignores hidden RGB at alpha zero; do not call this byte equality of original samples.
func pixels(_ url: URL) throws -> (width: Int, height: Int, bytes: [UInt8]) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 16_000_000 / height else {
        throw NSError(domain: "PixelComparison", code: 1)
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(width, height)
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
          let space = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw NSError(domain: "PixelComparison", code: 2)
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try bytes.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "PixelComparison", code: 3)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return (image.width, image.height, bytes)
}

@main enum ComparePixels {
    static func main() throws {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--dump-rgba" {
            let image = try pixels(URL(fileURLWithPath: CommandLine.arguments[2]))
            var data = Data()
            for value in [UInt32(image.width), UInt32(image.height)] {
                data.append(contentsOf: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) })
            }
            data.append(contentsOf: image.bytes)
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .withoutOverwriting)
            return
        }
        guard CommandLine.arguments.count == 3 else {
            FileHandle.standardError.write(Data("Usage: compare-pixels ORIGINAL OUTPUT\n".utf8))
            exit(2)
        }
        let a = try pixels(URL(fileURLWithPath: CommandLine.arguments[1]))
        let b = try pixels(URL(fileURLWithPath: CommandLine.arguments[2]))
        let sameSize = a.width == b.width && a.height == b.height
        var maximumDifference = 0
        var differentChannels = 0
        var alphaEqual = sameSize
        if sameSize {
            for i in a.bytes.indices {
                let difference = abs(Int(a.bytes[i]) - Int(b.bytes[i]))
                maximumDifference = max(maximumDifference, difference)
                if difference != 0 { differentChannels += 1 }
                if i % 4 == 3, difference != 0 { alphaEqual = false }
            }
        }
        let report: [String: Any] = [
            "normalization": "ImageIO orientation transform, sRGB, 8-bit premultiplied RGBA",
            "input_width": a.width, "input_height": a.height,
            "output_width": b.width, "output_height": b.height,
            "pixels_equal": sameSize && a.bytes == b.bytes,
            "maximum_channel_difference": sameSize ? maximumDifference as Any : NSNull(),
            "different_channels": sameSize ? differentChannels as Any : NSNull(),
            "alpha_equal": alphaEqual,
            "input_pixel_sha256": SHA256.hash(data: Data(a.bytes)).map { String(format: "%02x", $0) }.joined(),
            "output_pixel_sha256": SHA256.hash(data: Data(b.bytes)).map { String(format: "%02x", $0) }.joined()
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(sameSize && a.bytes == b.bytes ? 0 : 1)
    }
}
