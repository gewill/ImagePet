import Foundation
import CoreGraphics
import ImageIO
import Testing
import zlib
@testable import ImagePetCore

struct LosslessPNGOptimizerTests {
    // Independently generated PNG streams cover all five PNG filters, odd row widths,
    // 1/2/4/8-bit palette boundaries, and multiple alpha values. ImageIO is the decoder oracle.
    static let fixtures = [
        "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"
    ]

    @Test(arguments: fixtures.indices)
    func preservesPixelsAndMetadata(index: Int) throws {
        let input = try #require(Data(base64Encoded: Self.fixtures[index]))
        let result = LosslessPNGOptimizer.optimize(input)
        #expect(result.count < input.count)
        // A regular gradient can compress better as truecolor than as an 8-bit palette.
        if index != 3 { #expect(result[25] == 3) }
        #expect(try pixels(result) == pixels(input))
        #expect(result.range(of: Data("Comment\0preserve this".utf8)) != nil)
        #expect(result.range(of: Data("sRGB".utf8)) != nil)
        #expect(LosslessPNGOptimizer.optimize(result).count <= result.count)
    }

    @Test func invalidInputIsUnchanged() throws {
        let input = try #require(Data(base64Encoded: Self.fixtures[0]))
        for count in [0, 7, 15, input.count - 1] {
            let truncated = Data(input.prefix(count))
            #expect(LosslessPNGOptimizer.optimize(truncated) == truncated)
        }
        var corrupt = input
        corrupt[40] ^= 1
        #expect(LosslessPNGOptimizer.optimize(corrupt) == corrupt)
    }

    @Test(arguments: [false, true])
    func reportsActualSavedSizeAfterAtomicReplacement(overwrite: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("size.png")
        var input = try #require(Data(base64Encoded: Self.fixtures[0]))
        // Valid large metadata chunk ensures the stripped output is smaller in either save mode.
        let payload = Array("tEXtComment\0".utf8) + [UInt8](repeating: 65, count: 8192)
        let crc = payload.withUnsafeBufferPointer { UInt32(crc32(0, $0.baseAddress, uInt($0.count))) }
        func bigEndian(_ value: UInt32) -> [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }
        let chunk = bigEndian(UInt32(payload.count - 4)) + payload + bigEndian(crc)
        input.insert(contentsOf: chunk, at: input.count - 12)
        try input.write(to: url)
        let result = try await ImageCompressor().compress(
            inputURL: url, outputDirectory: overwrite ? nil : directory,
            compressionOptions: CompressionOptions(format: .png),
            saveOptions: SaveOptions(locationMode: overwrite ? .overwrite : .designated)
        )
        let actual = try Data(contentsOf: result.outputURL).count
        #expect(result.compressedSize == Int64(actual))
        #expect(result.originalSize == Int64(input.count))
        #expect(result.compressedSize < result.originalSize)
        if overwrite { #expect(result.outputURL == url) }
        else { #expect(try Data(contentsOf: url) == input) }
    }

    @Test(arguments: [2, 4, 16, 256])
    func exactPalettePreservesUnassociatedRGBA(colorCount: Int) throws {
        let width = 1025, height = 17
        let colors: [[UInt8]] = (0..<colorCount).map { i in
            [UInt8(i), UInt8(255 - i), UInt8(i / 2), i % 3 == 0 ? 0 : UInt8(i % 2 == 0 ? 127 : 255)]
        }
        var filtered: [UInt8] = []
        var expected: [UInt8] = []
        var state: UInt32 = 42
        for _ in 0..<height {
            filtered.append(0)
            for _ in 0..<width {
                state = state &* 1664525 &+ 1013904223
                let rgba = colors[Int(state >> 24) % colorCount]
                filtered += rgba
                expected += rgba
            }
        }
        let source = makePNG(width: width, height: height, depth: 8, colorType: 6, filtered: filtered)
        let result = LosslessPNGOptimizer.optimize(source)
        #expect(result.count < source.count)
        try #require(result[25] == 3)
        let chunks = pngChunks(result)
        let palette = try #require(chunks["PLTE"])
        let alpha = chunks["tRNS"] ?? []
        let depth = Int(result[24])
        let stride = (width * depth + 7) / 8 + 1
        var scanlines = [UInt8](repeating: 0, count: stride * height)
        var count = uLongf(scanlines.count)
        let packed = try #require(chunks["IDAT"])
        let status = scanlines.withUnsafeMutableBufferPointer { dst in
            packed.withUnsafeBufferPointer { src in uncompress(dst.baseAddress, &count, src.baseAddress, uLong(src.count)) }
        }
        try #require(status == Z_OK && count == scanlines.count)
        var actual: [UInt8] = []
        for y in 0..<height {
            // Indexed candidate emits unfiltered rows; check packed samples directly, without
            // color management or premultiplication that would hide RGB changes at alpha zero.
            try #require(scanlines[y * stride] == 0)
            for x in 0..<width {
                let byte = Int(scanlines[y * stride + 1 + x * depth / 8])
                let index = (byte >> (8 - depth - x * depth % 8)) & ((1 << depth) - 1)
                actual += Array(palette[(index * 3)..<(index * 3 + 3)])
                actual.append(index < alpha.count ? alpha[index] : 255)
            }
        }
        #expect(actual == expected)
    }

    @Test func unsupportedAndOversizedLayoutsStayUnchanged() throws {
        let input = try #require(Data(base64Encoded: Self.fixtures[0]))
        for type in ["acTL", "vpAG"] {
            var withChunk = input
            withChunk.insert(contentsOf: pngChunk(type, [0, 0, 0, 1, 0, 0, 0, 0]), at: 33)
            #expect(LosslessPNGOptimizer.optimize(withChunk) == withChunk)
        }
        // Valid CRC but unreasonable dimensions: reject before allocating/decompressing rows.
        let huge = makePNG(width: 1_000_000, height: 1_000_000, depth: 8, colorType: 6, filtered: [0])
        #expect(LosslessPNGOptimizer.optimize(huge) == huge)
        // Sixteen-bit samples must never take the 8-bit palette path.
        let raw: [UInt8] = [0, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]
        let sixteen = makePNG(width: 1, height: 1, depth: 16, colorType: 6, filtered: raw)
        let optimized = LosslessPNGOptimizer.optimize(sixteen)
        #expect(optimized[24] == 16 && optimized[25] == 6)
        let compressed = try #require(pngChunks(optimized)["IDAT"])
        var decoded = [UInt8](repeating: 0, count: raw.count)
        var size = uLongf(decoded.count)
        let status = decoded.withUnsafeMutableBufferPointer { dst in
            compressed.withUnsafeBufferPointer { src in uncompress(dst.baseAddress, &size, src.baseAddress, uLong(src.count)) }
        }
        #expect(status == Z_OK)
        #expect(decoded == raw)
    }

    @Test func moreThan256ColorsAndTransparencyMetadataStayTruecolor() throws {
        var row: [UInt8] = [0]
        for i in 0..<257 { row += [UInt8(truncatingIfNeeded: i), UInt8(i / 256), 17, 255] }
        let source = makePNG(width: 257, height: 1, depth: 8, colorType: 6, filtered: row)
        let result = LosslessPNGOptimizer.optimize(source)
        #expect(result[25] == 6)
        #expect(try pixels(result) == pixels(source))
        var keyed = makePNG(width: 2, height: 1, depth: 8, colorType: 2, filtered: [0, 10, 20, 30, 40, 50, 60])
        keyed.insert(contentsOf: pngChunk("tRNS", [0, 10, 0, 20, 0, 30]), at: 33)
        let optimized = LosslessPNGOptimizer.optimize(keyed)
        #expect(optimized[25] == 2)
        #expect(pngChunks(optimized)["tRNS"] == [0, 10, 0, 20, 0, 30])
        #expect(try pixels(optimized) == pixels(keyed))
    }

    private func makePNG(width: Int, height: Int, depth: UInt8, colorType: UInt8, filtered: [UInt8]) -> Data {
        var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(filtered.count))))
        var length = uLongf(compressed.count)
        _ = compressed.withUnsafeMutableBufferPointer { dst in
            filtered.withUnsafeBufferPointer { src in compress2(dst.baseAddress, &length, src.baseAddress, uLong(src.count), 0) }
        }
        let header = be(UInt32(width)) + be(UInt32(height)) + [depth, colorType, 0, 0, 0]
        return Data([137, 80, 78, 71, 13, 10, 26, 10] + pngChunk("IHDR", header)
                    + pngChunk("IDAT", Array(compressed.prefix(Int(length)))) + pngChunk("IEND", []))
    }

    private func be(_ value: UInt32) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
    }

    private func pngChunk(_ type: String, _ bytes: [UInt8]) -> [UInt8] {
        let payload = Array(type.utf8) + bytes
        let crc = payload.withUnsafeBufferPointer { UInt32(crc32(0, $0.baseAddress, uInt($0.count))) }
        return be(UInt32(bytes.count)) + payload + be(crc)
    }

    private func pngChunks(_ data: Data) -> [String: [UInt8]] {
        let bytes = [UInt8](data)
        var offset = 8
        var result: [String: [UInt8]] = [:]
        while offset + 12 <= bytes.count {
            let length = bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            let name = String(bytes: bytes[(offset + 4)..<(offset + 8)], encoding: .ascii)!
            result[name, default: []] += bytes[(offset + 8)..<(offset + 8 + length)]
            offset += length + 12
        }
        return result
    }

    private func pixels(_ data: Data) throws -> [UInt8] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                 bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}
