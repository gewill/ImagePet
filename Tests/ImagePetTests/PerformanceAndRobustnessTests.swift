import XCTest
import ImagePetCore
import Foundation
import QuartzCore
import Darwin.Mach

final class PerformanceAndRobustnessTests: XCTestCase {

    func testPerformanceMemoryAndRobustness() async throws {
        let root = packageRoot()
        let fixtureRoot = root.appendingPathComponent("TestImages/Apple", isDirectory: true)
        let inputDirectories = [
            fixtureRoot.appendingPathComponent("originals", isDirectory: true),
            fixtureRoot.appendingPathComponent("derived", isDirectory: true)
        ]

        guard inputDirectories.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            throw XCTSkip("Local Apple fixtures are not present.")
        }

        let outputDirectory = fixtureRoot.appendingPathComponent("output-performance-test", isDirectory: true)
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        var inputs = inputDirectories
            .flatMap { directory in
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
            }
            .filter(SupportedImageFormat.isSupported)

        XCTAssertFalse(inputs.isEmpty, "No input images found")

        // Duplicate the files to ensure we have at least 20 images
        while inputs.count < 20 {
            inputs.append(contentsOf: inputs)
        }
        inputs = Array(inputs.prefix(20))

        // Inject one invalid/corrupt URL to test robustness (does not abort batch)
        let invalidURL = fixtureRoot.appendingPathComponent("nonexistent_image_to_test_robustness.jpg")
        inputs.insert(invalidURL, at: 5) // Insert somewhere in the middle

        let startTime = CACurrentMediaTime()
        let maxConcurrency = 2
        let compressor = ImageCompressor()
        var peakMemoryBytes: UInt64 = 0

        // DispatchQueue for thread-safe access to statistics
        let syncQueue = DispatchQueue(label: "org.gewill.ImagePet.testSync")
        var completedCount = 0
        var successCount = 0
        var skippedCount = 0
        var failureCount = 0

        func recordMemory() {
            if let currentMem = getResidentMemory() {
                syncQueue.sync {
                    peakMemoryBytes = max(peakMemoryBytes, currentMem)
                }
            }
        }

        // Initialize allocator reservations
        await compressor.resetReservations()

        // Run concurrent compression matching queue behavior (max 2 concurrent workers)
        await withTaskGroup(of: Void.self) { group in
            var iterator = inputs.makeIterator()

            // Spawn up to maxConcurrency workers
            for _ in 0..<maxConcurrency {
                if let nextURL = iterator.next() {
                    group.addTask {
                        await processURL(nextURL)
                    }
                }
            }

            // As workers finish, feed them new URLs
            while await group.next() != nil {
                recordMemory()
                if let nextURL = iterator.next() {
                    group.addTask {
                        await processURL(nextURL)
                    }
                }
            }
        }

        func processURL(_ url: URL) async {
            do {
                _ = try await compressor.compress(
                    inputURL: url,
                    outputDirectory: outputDirectory,
                    preset: .balanced
                )
                syncQueue.sync {
                    completedCount += 1
                    successCount += 1
                }
            } catch let error as CompressionError where error == .skipped {
                syncQueue.sync {
                    completedCount += 1
                    skippedCount += 1
                }
            } catch {
                syncQueue.sync {
                    completedCount += 1
                    failureCount += 1
                }
            }
            recordMemory()
        }

        let duration = CACurrentMediaTime() - startTime

        print("""
        --- Performance and Robustness Test Results ---
        Total Completed Jobs: \(completedCount)
        Successful Jobs: \(successCount)
        Failed Jobs (Expected 1): \(failureCount)
        Total Time Taken: \(String(format: "%.2f", duration)) seconds
        Peak Resident Memory (RSS): \(byteString(Int64(peakMemoryBytes)))
        """)

        // Assertions matching verification criteria
        XCTAssertEqual(completedCount, 21, "Should process all 20 images + 1 invalid image")
        XCTAssertEqual(successCount + skippedCount, 20, "Should successfully process (compress or skip) 20 valid images")
        XCTAssertEqual(failureCount, 1, "Should fail exactly 1 invalid image (robustness test)")
        XCTAssertLessThan(duration, 30.0, "Compression should complete in under 30 seconds")

        let memoryLimit: UInt64 = 1500 * 1024 * 1024 // 1.5 GB
        XCTAssertLessThan(peakMemoryBytes, memoryLimit, "Memory footprint should remain below 1.5 GB")
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func getResidentMemory() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? UInt64(info.resident_size) : nil
    }
}
