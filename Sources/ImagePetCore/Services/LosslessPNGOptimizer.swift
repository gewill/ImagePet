import Foundation
import zlib

/// Optimizes ImageIO's finished PNG, preserving its normalized pixels and ancillary data.
/// Unsupported layouts and exhausted budgets keep the original encoded candidate.
/// PNG filters and palette packing follow https://www.w3.org/TR/png-3/.
enum LosslessPNGOptimizer {
    static let maximumInflatedBytes = 64 * 1024 * 1024
    private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    static func optimize(_ data: Data) -> Data {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        guard data.count <= maximumInflatedBytes,
              let chunks = parse(data), let header = chunks.first, header.type == "IHDR",
              header.bytes.count == 13,
              !chunks.contains(where: { ["acTL", "fcTL", "fdAT"].contains($0.type) }) else { return data }
        let h = header.bytes
        let width = integer(h, 0), height = integer(h, 4)
        let channels: Int
        switch h[9] {
        case 0: channels = 1
        case 2: channels = 3
        case 3: channels = 1
        case 4: channels = 2
        case 6: channels = 4
        default: return data
        }
        let validDepths = h[9] == 3 ? [1, 2, 4, 8] : (h[9] == 0 ? [1, 2, 4, 8, 16] : [8, 16])
        guard width > 0, height > 0, width <= maximumInflatedBytes, height <= maximumInflatedBytes,
              validDepths.contains(Int(h[8])), h[10] == 0, h[11] == 0, h[12] == 0 else { return data }
        let rowBytes = (width * channels * Int(h[8]) + 7) / 8
        guard rowBytes < maximumInflatedBytes,
              height <= maximumInflatedBytes / (rowBytes + 1) else { return data }
        let compressed = chunks.filter { $0.type == "IDAT" }.flatMap(\.bytes)
        guard !compressed.isEmpty,
              let filtered = inflate(compressed, count: (rowBytes + 1) * height) else { return data }
        var best = data
        // Exact palettes are the useful asset path: evaluate them before spending effort
        // recompressing a truecolor stream that ImageIO has already compressed well.
        let incompatible = ["PLTE", "tRNS", "bKGD", "hIST", "sBIT"]
        if h[8] == 8, [2, 6].contains(h[9]),
           !chunks.contains(where: { incompatible.contains($0.type) }),
           let indexed = paletteCandidate(filtered, width: width, height: height, channels: channels,
                                          chunks: chunks, deadline: deadline), indexed.count < best.count {
            best = indexed
        }
        // Photos rarely benefit from another deflate pass. Retain a short attempt for
        // compact streams (text, flat art, gradients), with explicit work and time limits.
        // Exact palette outputs already receive their own final lossless deflate pass.
        let compactStream = filtered.count <= 8 * 1_048_576 && compressed.count <= filtered.count / 20
        if filtered.count <= 1_048_576 || compactStream,
           let packed = deflate(filtered, deadline: min(deadline, ProcessInfo.processInfo.systemUptime + 0.08)) {
            let candidate = replacingImageData(chunks, packed: packed)
            if candidate.count < best.count { best = candidate }
        }
        return best
    }

    private struct Chunk {
        let type: String
        var bytes: [UInt8]
    }

    private static func parse(_ data: Data) -> [Chunk]? {
        let bytes = [UInt8](data)
        guard bytes.count >= 20, Array(bytes.prefix(8)) == signature else { return nil }
        var chunks: [Chunk] = []
        var offset = 8
        var sawData = false
        var endedData = false
        // Unknown critical or unsafe-to-copy chunks require an implementation that understands them.
        let understood = Set(["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "bKGD", "hIST", "sBIT",
                              "cHRM", "gAMA", "iCCP", "sRGB", "cICP", "mDCv", "cLLi", "pHYs", "eXIf",
                              "tEXt", "zTXt", "iTXt", "tIME"])
        while offset + 12 <= bytes.count {
            let length = integer(bytes, offset)
            guard length <= bytes.count - offset - 12 else { return nil }
            let name = Array(bytes[(offset + 4)..<(offset + 8)])
            guard name.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }),
                  let type = String(bytes: name, encoding: .ascii),
                  understood.contains(type) || (name[0] & 32 != 0 && name[3] & 32 != 0) else { return nil }
            let payload = Array(bytes[(offset + 8)..<(offset + 8 + length)])
            guard checksum(name + payload) == UInt32(integer(bytes, offset + 8 + length)) else { return nil }
            if type == "IHDR", !chunks.isEmpty { return nil }
            if type == "IDAT" {
                guard !endedData else { return nil }
                sawData = true
            } else if sawData { endedData = true }
            chunks.append(Chunk(type: type, bytes: payload))
            offset += length + 12
            if type == "IEND" { return offset == bytes.count && length == 0 && sawData ? chunks : nil }
        }
        return nil
    }

    private static func paletteCandidate(_ filtered: [UInt8], width: Int, height: Int, channels: Int, chunks: [Chunk], deadline: TimeInterval) -> Data? {
        let stride = width * channels
        var previous = [UInt8](repeating: 0, count: stride)
        var row = previous
        var palette: [UInt32] = []
        var lookup: [UInt32: UInt8] = [:]
        var indices = [UInt8]()
        indices.reserveCapacity(width * height)
        for y in 0..<height {
            if y % 32 == 0, ProcessInfo.processInfo.systemUptime >= deadline { return nil }
            let start = y * (stride + 1)
            let filter = filtered[start]
            guard filter <= 4 else { return nil }
            for x in 0..<stride {
                let left = x >= channels ? Int(row[x - channels]) : 0
                let up = Int(previous[x])
                let upperLeft = x >= channels ? Int(previous[x - channels]) : 0
                let predictor: Int
                switch filter {
                case 0: predictor = 0
                case 1: predictor = left
                case 2: predictor = up
                case 3: predictor = (left + up) / 2
                default: predictor = paeth(left, up, upperLeft)
                }
                row[x] = filtered[start + 1 + x] &+ UInt8(predictor)
            }
            for x in 0..<width {
                let i = x * channels
                let alpha = channels == 4 ? row[i + 3] : 255
                let key = UInt32(row[i]) << 24 | UInt32(row[i + 1]) << 16 | UInt32(row[i + 2]) << 8 | UInt32(alpha)
                if let index = lookup[key] { indices.append(index) }
                else {
                    guard palette.count < 256 else { return nil }
                    let index = UInt8(palette.count)
                    palette.append(key)
                    lookup[key] = index
                    indices.append(index)
                }
            }
            swap(&previous, &row)
        }
        let depth = palette.count <= 2 ? 1 : palette.count <= 4 ? 2 : palette.count <= 16 ? 4 : 8
        let bytesPerRow = (width * depth + 7) / 8
        var raw = [UInt8](repeating: 0, count: height * (bytesPerRow + 1))
        for y in 0..<height {
            for x in 0..<width {
                let position = y * (bytesPerRow + 1) + 1 + x * depth / 8
                raw[position] |= indices[y * width + x] << (8 - depth - x * depth % 8)
            }
        }
        guard let packed = deflate(raw, deadline: deadline) else { return nil }
        var paletteBytes: [UInt8] = []
        var alphaBytes: [UInt8] = []
        for color in palette {
            paletteBytes += [UInt8(truncatingIfNeeded: color >> 24), UInt8(truncatingIfNeeded: color >> 16), UInt8(truncatingIfNeeded: color >> 8)]
            alphaBytes.append(UInt8(truncatingIfNeeded: color))
        }
        while alphaBytes.last == 255 { alphaBytes.removeLast() }
        var replacement = chunks
        replacement[0].bytes[8] = UInt8(depth)
        replacement[0].bytes[9] = 3
        var extra = [Chunk(type: "PLTE", bytes: paletteBytes)]
        if !alphaBytes.isEmpty { extra.append(Chunk(type: "tRNS", bytes: alphaBytes)) }
        return replacingImageData(replacement, packed: packed, beforeData: extra)
    }

    private static func replacingImageData(_ chunks: [Chunk], packed: [UInt8], beforeData: [Chunk] = []) -> Data {
        var output = Data(signature)
        var written = false
        for chunk in chunks {
            if chunk.type == "IDAT" {
                if !written {
                    for extra in beforeData { append(extra, to: &output) }
                    append(Chunk(type: "IDAT", bytes: packed), to: &output)
                    written = true
                }
            } else { append(chunk, to: &output) }
        }
        return output
    }

    private static func append(_ chunk: Chunk, to data: inout Data) {
        let payload = Array(chunk.type.utf8) + chunk.bytes
        data.append(contentsOf: bigEndian(UInt32(chunk.bytes.count)))
        data.append(contentsOf: payload)
        data.append(contentsOf: bigEndian(checksum(payload)))
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
    }

    private static func integer(_ bytes: [UInt8], _ offset: Int) -> Int {
        bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt32 {
        bytes.withUnsafeBufferPointer { UInt32(crc32(0, $0.baseAddress, uInt($0.count))) }
    }

    private static func inflate(_ bytes: [UInt8], count: Int) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: count)
        var length = uLongf(count)
        let status = output.withUnsafeMutableBufferPointer { destination in
            bytes.withUnsafeBufferPointer { source in
                uncompress(destination.baseAddress, &length, source.baseAddress, uLong(source.count))
            }
        }
        return status == Z_OK && length == count ? output : nil
    }

    private static func deflate(_ bytes: [UInt8], deadline: TimeInterval) -> [UInt8]? {
        var stream = z_stream()
        guard deflateInit_(&stream, Z_DEFAULT_COMPRESSION, ZLIB_VERSION,
                          Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { deflateEnd(&stream) }
        return bytes.withUnsafeBufferPointer { source in
            var output: [UInt8] = []
            var buffer = [UInt8](repeating: 0, count: 65_536)
            var offset = 0
            var status: Int32 = Z_OK
            while status != Z_STREAM_END {
                // Bounded input chunks make the budget observable during compression.
                // One zlib step is not preemptible; this is an effort budget, not a hard deadline.
                guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
                if stream.avail_in == 0, offset < source.count {
                    let count = min(32_768, source.count - offset)
                    stream.next_in = UnsafeMutablePointer(mutating: source.baseAddress!.advanced(by: offset))
                    stream.avail_in = uInt(count)
                    offset += count
                }
                let finishing = offset == source.count
                status = buffer.withUnsafeMutableBufferPointer { destination in
                    stream.next_out = destination.baseAddress
                    stream.avail_out = uInt(destination.count)
                    return zlib.deflate(&stream, finishing ? Z_FINISH : Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else { return nil }
                output.append(contentsOf: buffer.prefix(buffer.count - Int(stream.avail_out)))
            }
            return output
        }
    }

    private static func paeth(_ a: Int, _ b: Int, _ c: Int) -> Int {
        let p = a + b - c
        let pa = abs(p - a), pb = abs(p - b), pc = abs(p - c)
        return pa <= pb && pa <= pc ? a : pb <= pc ? b : c
    }
}
