import Foundation
import ArgumentParser
import ImagePetCore

extension CompressionPreset: ExpressibleByArgument {}
extension OutputFormat: ExpressibleByArgument {}

extension MaxDimensionLimit: ExpressibleByArgument {
    public init?(argument: String) {
        if argument.lowercased() == "none" {
            self = .none
        } else if let match = MaxDimensionLimit.allCases.first(where: { $0.rawValue == argument }) {
            self = match
        } else {
            return nil
        }
    }
}

struct ImagePetCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "imagepet",
        abstract: "ImagePet: A fast local image compressor.",
        discussion: "Specify one or more image files or directories. The tool will compress them locally.",
        version: "1.0.0"
    )

    @Argument(help: "Input image files or directories.")
    var inputs: [String]

    @Option(name: .customShort("o"), help: "Designated output directory. If not specified, outputs to the original folder.")
    var output: String?

    @Option(name: .customShort("p"), help: "Compression preset: high, balanced, small. Default: balanced.")
    var preset: CompressionPreset = .balanced

    @Option(name: .customShort("q"), help: "Custom quality (1-100). Mutually exclusive with preset.")
    var quality: Int?

    @Option(name: .customShort("f"), help: "Output format: original, jpeg, png, heic, webp. Default: original.")
    var format: OutputFormat = .original

    @Option(name: .customShort("m"), help: "Max dimension limit (none, 1024, 1920, 2048, 3840). Default: none.")
    var maxDim: MaxDimensionLimit = .none

    @Flag(help: "Keep image EXIF/GPS metadata (default is to strip).")
    var keepMetadata: Bool = false

    @Flag(help: "Allow overwriting original files if saving to original folder.")
    var overwrite: Bool = false

    func validate() throws {
        if quality != nil && preset != .balanced {
            throw ValidationError("Cannot specify both custom quality (-q) and preset (-p).")
        }
        if let q = quality, (q < 1 || q > 100) {
            throw ValidationError("Custom quality (-q) must be between 1 and 100.")
        }
        if inputs.isEmpty {
            throw ValidationError("At least one input file or directory must be specified.")
        }
        if let output = output {
            let outputURL = URL(fileURLWithPath: output).absoluteURL
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &isDir) || !isDir.boolValue {
                throw ValidationError("Output directory does not exist or is not a directory: \(output)")
            }
        }
        if overwrite && output != nil {
            throw ValidationError("Cannot specify both --overwrite and designated output directory (-o).")
        }
    }

    func run() throws {
        var runError: Error?
        let finished = DispatchSemaphore(value: 0)

        Task {
            do {
                try await runCompression()
            } catch {
                runError = error
            }
            finished.signal()
        }

        finished.wait()

        if let runError {
            throw runError
        }
    }

    private func runCompression() async throws {
        // 1. Collect files
        let files = collectFiles(from: inputs)
        guard !files.isEmpty else {
            print("No supported image files found in the specified inputs.")
            throw ExitCode(1)
        }

        print("Found \(files.count) image file(s) to process.")

        // 2. Set up compressor
        let compressor = ImageCompressor()

        // Determine quality setting
        let targetQuality: CompressionQuality
        if let q = quality {
            targetQuality = .custom(q)
        } else {
            targetQuality = .preset(preset)
        }

        // Options
        let compressionOptions = CompressionOptions(
            lossyQuality: targetQuality,
            format: format,
            jpegEncodingMode: .advanced, // Always use advanced/mozjpeg engine for CLI
            maxDimension: maxDim,
            stripMetadata: !keepMetadata
        )

        let saveLocation: SaveLocationMode
        if overwrite {
            saveLocation = .overwrite
        } else if output != nil {
            saveLocation = .designated
        } else {
            saveLocation = .originalFolder
        }

        let saveOptions = SaveOptions(
            locationMode: saveLocation,
            suffix: "_compressed",
            overwritePolicy: .replaceOriginalKeepingFormat
        )

        let outputDirURL = output.map { URL(fileURLWithPath: $0).absoluteURL }

        // 3. Process queue (concurrency limit = 2)
        let concurrencyLimit = 2
        var succeededCount = 0
        var failedCount = 0
        var totalOriginalSize: Int64 = 0
        var totalCompressedSize: Int64 = 0

        print("Starting batch compression (max concurrency: \(concurrencyLimit))...")

        await withTaskGroup(of: TaskResult.self) { group in
            var index = 0

            // Spawn initial tasks
            while index < min(concurrencyLimit, files.count) {
                let file = files[index]
                group.addTask {
                    await compressFile(file, compressor: compressor, outputDir: outputDirURL, compOptions: compressionOptions, saveOptions: saveOptions)
                }
                index += 1
            }

            // Loop through completed tasks and spawn next
            for await result in group {
                switch result {
                case .success(let originalSize, let compressedSize, let inputPath, let outputPath):
                    succeededCount += 1
                    totalOriginalSize += originalSize
                    totalCompressedSize += compressedSize
                    let savings = originalSize > compressedSize ? originalSize - compressedSize : 0
                    let ratio = originalSize > 0 ? Double(savings) / Double(originalSize) * 100 : 0
                    print("  [Done] \(inputPath) -> \(outputPath) (\(formatBytes(originalSize)) -> \(formatBytes(compressedSize)), Saved \(String(format: "%.1f", ratio))%)")

                case .failure(let error, let inputPath):
                    failedCount += 1
                    print("  [Failed] \(inputPath): \(error.localizedDescription)")
                }

                if index < files.count {
                    let file = files[index]
                    group.addTask {
                        await compressFile(file, compressor: compressor, outputDir: outputDirURL, compOptions: compressionOptions, saveOptions: saveOptions)
                    }
                    index += 1
                }
            }
        }

        // 4. Summary
        print("\n--- Summary ---")
        print("Total Files: \(files.count)")
        print("Succeeded:   \(succeededCount)")
        print("Failed:      \(failedCount)")
        if succeededCount > 0 {
            print("Ate:         \(formatBytes(totalOriginalSize))")
            print("Pooped:      \(formatBytes(totalCompressedSize))")
            let totalSavings = totalOriginalSize > totalCompressedSize ? totalOriginalSize - totalCompressedSize : 0
            let totalRatio = totalOriginalSize > 0 ? Double(totalSavings) / Double(totalOriginalSize) * 100 : 0
            print("Saved:       \(formatBytes(totalSavings)) (\(String(format: "%.1f", totalRatio))%)")
        }

        if failedCount > 0 {
            throw ExitCode(1)
        }
    }

    private func collectFiles(from paths: [String]) -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default
        for path in paths {
            let url = URL(fileURLWithPath: path).absoluteURL
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            if let attrs = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                               attrs.isRegularFile ?? false {
                                if SupportedImageFormat.isSupported(fileURL) {
                                    urls.append(fileURL)
                                }
                            }
                        }
                    }
                } else {
                    if SupportedImageFormat.isSupported(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }

    private func compressFile(
        _ fileURL: URL,
        compressor: ImageCompressor,
        outputDir: URL?,
        compOptions: CompressionOptions,
        saveOptions: SaveOptions
    ) async -> TaskResult {
        do {
            let result = try await compressor.compress(
                inputURL: fileURL,
                outputDirectory: outputDir,
                compressionOptions: compOptions,
                saveOptions: saveOptions
            )
            return .success(
                originalSize: result.originalSize,
                compressedSize: result.compressedSize,
                inputPath: fileURL.lastPathComponent,
                outputPath: result.outputURL.lastPathComponent
            )
        } catch {
            return .failure(error: error, inputPath: fileURL.lastPathComponent)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum TaskResult {
    case success(originalSize: Int64, compressedSize: Int64, inputPath: String, outputPath: String)
    case failure(error: Error, inputPath: String)
}

ImagePetCLI.main()
