import XCTest

final class ImagePetCLITests: XCTestCase {
    func testCLIVersionAndHelp() throws {
        let result = try runCLI(arguments: ["--help"])

        XCTAssertEqual(result.exitCode, 0)

        let output = result.standardOutput
        XCTAssertTrue(output.contains("OVERVIEW: ImagePet: A fast local image compressor."))
        XCTAssertTrue(output.contains("USAGE: imagepet"))
        XCTAssertTrue(output.contains("OPTIONS:"))
    }

    func testCLIValidationErrorWithoutInputs() throws {
        let result = try runCLI(arguments: [])

        XCTAssertNotEqual(result.exitCode, 0)

        XCTAssertTrue(result.standardError.contains("Error: Missing expected argument"))
    }

    private func runCLI(arguments: [String], timeout: TimeInterval = 5) throws -> CLIResult {
        let executableURL = try findCLIExecutable()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let finished = XCTestExpectation(description: "CLI process finished")
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            finished.fulfill()
        }

        let waitResult = XCTWaiter.wait(for: [finished], timeout: timeout)
        if waitResult != .completed {
            process.terminate()
            XCTFail("imagepet CLI timed out after \(timeout) seconds")
            process.waitUntilExit()
            return CLIResult(exitCode: -1, standardOutput: "", standardError: "")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let standardOutput = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return CLIResult(
            exitCode: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: errorOutput
        )
    }

    private func findCLIExecutable() throws -> URL {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let path = environment["IMAGEPET_CLI_PATH"], fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        var candidates: [URL] = []

        if let productsDirectory = environment["BUILT_PRODUCTS_DIR"] {
            let directoryURL = URL(fileURLWithPath: productsDirectory, isDirectory: true)
            candidates.append(directoryURL.appendingPathComponent("ImagePetCLI"))
            candidates.append(directoryURL.appendingPathComponent("imagepet"))
        }

        let testProductsDirectory = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        candidates.append(testProductsDirectory.appendingPathComponent("ImagePetCLI"))
        candidates.append(testProductsDirectory.appendingPathComponent("imagepet"))

        let packageRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        candidates.append(packageRoot.appendingPathComponent(".build/debug/imagepet"))
        candidates.append(packageRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/imagepet"))

        if let executable = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) {
            return executable
        }

        throw XCTSkip("imagepet executable is not built; build the ImagePetCLI target or set IMAGEPET_CLI_PATH.")
    }
}

private struct CLIResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}
