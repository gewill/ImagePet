import XCTest
import ImageIO
import WebP
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

    func testWebPDecodingBenchmark() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let sizes = [
            ("small", 128, 128, true),
            ("medium", 800, 600, false),
            ("large", 2048, 1536, true)
        ]

        var report = ""
        report += "# WebP Decoding Engines Performance Benchmark\n\n"
        report += "Target OS: macOS 13+ / Sonoma+\n\n"
        report += "| File Size/Type | Engine | Avg Time (ms) | Loop Count | Peak Mem Delta (MB) |\n"
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

            // Convert to WebP using SwiftWebPEncodingEngine to get WebP data
            let webpOut = directory.appendingPathComponent("\(name).webp")
            try SwiftWebPEncodingEngine().encode(
                image: cgImage,
                source: sourceMetadata,
                destinationTemporaryURL: webpOut,
                options: CompressionOptions(lossyQuality: .custom(80), format: .webp)
            )

            let webpData = try Data(contentsOf: webpOut)
            let loopCount = 20

            // 1. Benchmark ImageIO Decoding
            let startIOMem = getMemoryRSS()
            let startIO = DispatchTime.now()
            for _ in 0..<loopCount {
                autoreleasepool {
                    guard let ioSource = CGImageSourceCreateWithData(webpData as CFData, nil),
                          let _ = CGImageSourceCreateImageAtIndex(ioSource, 0, nil) else {
                        XCTFail("ImageIO failed to decode WebP")
                        return
                    }
                }
            }
            let endIO = DispatchTime.now()
            let endIOMem = getMemoryRSS()
            let ioTime = Double(endIO.uptimeNanoseconds - startIO.uptimeNanoseconds) / 1_000_000.0 / Double(loopCount)
            let ioDeltaMem = Double(max(0, Int64(endIOMem) - Int64(startIOMem))) / 1024.0 / 1024.0

            report += "| \(name) (\(w)x\(h), alpha: \(alpha)) | ImageIO | \(String(format: "%.2f", ioTime)) | \(loopCount) | \(String(format: "%.2f", ioDeltaMem)) |\n"

            // 2. Benchmark libwebp Decoding
            let startLibMem = getMemoryRSS()
            let startLib = DispatchTime.now()
            for _ in 0..<loopCount {
                autoreleasepool {
                    do {
                        _ = try WebPDecoder().decodeCGImage(from: webpData, options: WebPDecoderOptions())
                    } catch {
                        XCTFail("libwebp failed to decode WebP: \(error)")
                    }
                }
            }
            let endLib = DispatchTime.now()
            let endLibMem = getMemoryRSS()
            let libTime = Double(endLib.uptimeNanoseconds - startLib.uptimeNanoseconds) / 1_000_000.0 / Double(loopCount)
            let libDeltaMem = Double(max(0, Int64(endLibMem) - Int64(startLibMem))) / 1024.0 / 1024.0

            report += "| | libwebp | \(String(format: "%.2f", libTime)) | \(loopCount) | \(String(format: "%.2f", libDeltaMem)) |\n"
        }

        // Benchmark FreeLarge images if available
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/ImagePetCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // root/
        let freeLargeDir = root.appendingPathComponent("TestImages/FreeLarge", isDirectory: true)

        if let contents = try? FileManager.default.contentsOfDirectory(at: freeLargeDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
           let largeURL = contents.first(where: { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }) {

            print("--- Benchmarking with FreeLarge Image: \(largeURL.lastPathComponent) ---")

            if let largeSource = CGImageSourceCreateWithURL(largeURL as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(largeSource, 0, nil) {

                let w = cgImage.width
                let h = cgImage.height
                let alpha = cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast && cgImage.alphaInfo != .noneSkipFirst

                let sourceMetadata = ImageSourceMetadata(
                    format: SupportedImageFormat.format(for: largeURL) ?? .png,
                    pixelWidth: w,
                    pixelHeight: h,
                    hasAlpha: alpha
                )

                let webpOut = directory.appendingPathComponent("freelarge.webp")
                try SwiftWebPEncodingEngine().encode(
                    image: cgImage,
                    source: sourceMetadata,
                    destinationTemporaryURL: webpOut,
                    options: CompressionOptions(lossyQuality: .custom(80), format: .webp)
                )

                let webpData = try Data(contentsOf: webpOut)
                let loopCount = 3 // For large files, low loop count to prevent timeout

                // ImageIO Decode
                let startIOMem = getMemoryRSS()
                let startIO = DispatchTime.now()
                for _ in 0..<loopCount {
                    autoreleasepool {
                        guard let ioSource = CGImageSourceCreateWithData(webpData as CFData, nil),
                              let _ = CGImageSourceCreateImageAtIndex(ioSource, 0, nil) else {
                            XCTFail("ImageIO failed to decode WebP Freelarge")
                            return
                        }
                    }
                }
                let endIO = DispatchTime.now()
                let endIOMem = getMemoryRSS()
                let ioTime = Double(endIO.uptimeNanoseconds - startIO.uptimeNanoseconds) / 1_000_000.0 / Double(loopCount)
                let ioDeltaMem = Double(max(0, Int64(endIOMem) - Int64(startIOMem))) / 1024.0 / 1024.0

                report += "| FreeLarge (\(largeURL.lastPathComponent), \(w)x\(h)) | ImageIO | \(String(format: "%.2f", ioTime)) | \(loopCount) | \(String(format: "%.2f", ioDeltaMem)) |\n"

                // libwebp Decode
                let startLibMem = getMemoryRSS()
                let startLib = DispatchTime.now()
                for _ in 0..<loopCount {
                    autoreleasepool {
                        do {
                            _ = try WebPDecoder().decodeCGImage(from: webpData, options: WebPDecoderOptions())
                        } catch {
                            XCTFail("libwebp failed to decode WebP Freelarge: \(error)")
                        }
                    }
                }
                let endLib = DispatchTime.now()
                let endLibMem = getMemoryRSS()
                let libTime = Double(endLib.uptimeNanoseconds - startLib.uptimeNanoseconds) / 1_000_000.0 / Double(loopCount)
                let libDeltaMem = Double(max(0, Int64(endLibMem) - Int64(startLibMem))) / 1024.0 / 1024.0

                report += "| | libwebp | \(String(format: "%.2f", libTime)) | \(loopCount) | \(String(format: "%.2f", libDeltaMem)) |\n"
            }
        }

        // 3. Concurrent Decode Test
        let name = "medium"
        let w = 800
        let h = 600
        let pngURL = directory.appendingPathComponent("\(name)_con.png")
        try writeSampleImage(width: w, height: h, hasAlpha: false, to: pngURL)
        guard let source = CGImageSourceCreateWithURL(pngURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Could not read con sample")
            return
        }
        let webpOut = directory.appendingPathComponent("\(name)_con.webp")
        try SwiftWebPEncodingEngine().encode(
            image: cgImage,
            source: ImageSourceMetadata(format: .png, pixelWidth: w, pixelHeight: h, hasAlpha: false),
            destinationTemporaryURL: webpOut,
            options: CompressionOptions(lossyQuality: .custom(80), format: .webp)
        )
        let webpData = try Data(contentsOf: webpOut)

        let concurrentCount = 15

        let startConIO = DispatchTime.now()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentCount {
                group.addTask {
                    autoreleasepool {
                        guard let ioSource = CGImageSourceCreateWithData(webpData as CFData, nil),
                              let _ = CGImageSourceCreateImageAtIndex(ioSource, 0, nil) else {
                            XCTFail("Concurrent ImageIO failed")
                            return
                        }
                    }
                }
            }
        }
        let endConIO = DispatchTime.now()
        let conIOTime = Double(endConIO.uptimeNanoseconds - startConIO.uptimeNanoseconds) / 1_000_000.0

        let startConLib = DispatchTime.now()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentCount {
                group.addTask {
                    autoreleasepool {
                        do {
                            _ = try WebPDecoder().decodeCGImage(from: webpData, options: WebPDecoderOptions())
                        } catch {
                            XCTFail("Concurrent libwebp failed")
                        }
                    }
                }
            }
        }
        let endConLib = DispatchTime.now()
        let conLibTime = Double(endConLib.uptimeNanoseconds - startConLib.uptimeNanoseconds) / 1_000_000.0

        report += "\n### Concurrent Decodes (\(concurrentCount) parallel tasks):\n"
        report += "- **ImageIO** Total Time: \(String(format: "%.2f", conIOTime)) ms\n"
        report += "- **libwebp** Total Time: \(String(format: "%.2f", conLibTime)) ms\n"

        print("\n=== DECODING BENCHMARK REPORT ===\n\(report)\n=================================\n")
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
