import XCTest
import ImageIO
@testable import ImagePetCore

final class WebPBenchmarkTests: XCTestCase {

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeSampleImage(width: Int, height: Int, hasAlpha: Bool, to url: URL) throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = hasAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            XCTFail("Failed to create context")
            return
        }

        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.3, alpha: hasAlpha ? 0.7 : 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                "public.png" as CFString,
                1,
                nil
              ) else {
            XCTFail("Failed to write sample")
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    func testWebPBenchmarkAndEvaluation() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let swiftWebPEngine = SwiftWebPEncodingEngine()
        let appleWebPEngine = AppleWebPEncodingEngine()

        let appleSupported = AppleWebPCapabilityProbe.canWriteWebP()
        print("--- WebP Benchmark: Apple native write support = \(appleSupported) ---")

        let sizes = [
            ("small", 128, 128, true),
            ("medium", 800, 600, false),
            ("large", 2048, 1536, true)
        ]

        var report = ""
        report += "# WebP Encoding Engines Benchmark & Adopt Decision\n\n"
        report += "Target OS: macOS 13+ / Sonoma+\n"
        report += "Apple native WebP write supported: \(appleSupported)\n\n"
        report += "| File Size/Type | Engine | Time (ms) | Output Size (bytes) | Peak Mem (MB) |\n"
        report += "| --- | --- | --- | --- | --- |\n"

        for (name, w, h, alpha) in sizes {
            let pngURL = directory.appendingPathComponent("\(name).png")
            try writeSampleImage(width: w, height: h, hasAlpha: alpha, to: pngURL)

            guard let source = CGImageSourceCreateWithURL(pngURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                XCTFail("Could not read sample image")
                return
            }

            let sourceMetadata = ImageSourceMetadata(
                format: .png,
                pixelWidth: w,
                pixelHeight: h,
                hasAlpha: alpha
            )

            let options = CompressionOptions(
                lossyQuality: .custom(80),
                format: .webp,
                maxDimension: .none,
                stripMetadata: true
            )

            // Benchmark SwiftWebPEngine
            let swiftOut = directory.appendingPathComponent("\(name)_swift.webp")
            let startSwiftMem = getMemoryRSS()
            let startSwift = DispatchTime.now()

            try swiftWebPEngine.encode(
                image: cgImage,
                source: sourceMetadata,
                destinationTemporaryURL: swiftOut,
                options: options
            )

            let endSwift = DispatchTime.now()
            let endSwiftMem = getMemoryRSS()
            let swiftTime = Double(endSwift.uptimeNanoseconds - startSwift.uptimeNanoseconds) / 1_000_000.0
            let swiftSize = (try? FileManager.default.attributesOfItem(atPath: swiftOut.path)[.size] as? Int64) ?? 0
            let swiftDeltaMem = Double(max(0, Int64(endSwiftMem) - Int64(startSwiftMem))) / 1024.0 / 1024.0

            report += "| \(name) (\(w)x\(h), alpha: \(alpha)) | Swift-WebP | \(String(format: "%.2f", swiftTime)) | \(swiftSize) | \(String(format: "%.2f", swiftDeltaMem)) |\n"

            // Benchmark AppleWebPEngine if supported
            if appleSupported {
                let appleOut = directory.appendingPathComponent("\(name)_apple.webp")
                let startAppleMem = getMemoryRSS()
                let startApple = DispatchTime.now()

                try appleWebPEngine.encode(
                    image: cgImage,
                    source: sourceMetadata,
                    destinationTemporaryURL: appleOut,
                    options: options
                )

                let endApple = DispatchTime.now()
                let endAppleMem = getMemoryRSS()
                let appleTime = Double(endApple.uptimeNanoseconds - startApple.uptimeNanoseconds) / 1_000_000.0
                let appleSize = (try? FileManager.default.attributesOfItem(atPath: appleOut.path)[.size] as? Int64) ?? 0
                let appleDeltaMem = Double(max(0, Int64(endAppleMem) - Int64(startAppleMem))) / 1024.0 / 1024.0

                report += "| | Apple-WebP | \(String(format: "%.2f", appleTime)) | \(appleSize) | \(String(format: "%.2f", appleDeltaMem)) |\n"

                // Let's also verify that the output of AppleWebPEngine can be decoded and has correct alpha/dimensions
                let decodedApple = try SwiftWebPDecodingEngine().decodeCGImage(from: try Data(contentsOf: appleOut), maxDimension: nil)
                XCTAssertEqual(decodedApple.width, w)
                XCTAssertEqual(decodedApple.height, h)
            } else {
                report += "| | Apple-WebP | N/A (Not Supported) | N/A | N/A |\n"
            }
        }

        print("\n=== BENCHMARK REPORT ===\n\(report)\n========================\n")
    }

    private func getMemoryRSS() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        return 0
    }
}
