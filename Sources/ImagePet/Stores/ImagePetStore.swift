import AppKit
import Foundation
import ImagePetCore

@MainActor
final class ImagePetStore: ObservableObject {
    @Published var jobs: [ImageJob] = []
    @Published var preset: CompressionPreset = .balanced
    @Published var outputDirectory: URL?
    @Published var petState: PetState = .idle
    @Published var isDropTargeted = false
    @Published var isProcessing = false
    @Published var outputFolderMessage: String?
    @Published var isDesktopPetVisible = false {
        didSet {
            defaults.set(isDesktopPetVisible, forKey: desktopPetVisibilityKey)
        }
    }
    @Published var outputFormat: OutputFormat = .original {
        didSet {
            defaults.set(outputFormat.rawValue, forKey: outputFormatKey)
        }
    }
    @Published var saveLocationMode: SaveLocationMode = .designated {
        didSet {
            defaults.set(saveLocationMode.rawValue, forKey: saveLocationModeKey)
        }
    }
    @Published var filenameSuffix: String = "_compressed" {
        didSet {
            defaults.set(filenameSuffix, forKey: filenameSuffixKey)
        }
    }
    @Published var maxDimension: MaxDimensionLimit = .none {
        didSet {
            defaults.set(maxDimension.rawValue, forKey: maxDimensionKey)
        }
    }
    @Published var stripMetadata: Bool = true {
        didSet {
            defaults.set(stripMetadata, forKey: stripMetadataKey)
        }
    }
    @Published var showOverwriteConfirmation = false
    var didConfirmOverwrite = false

    let maxConcurrentJobs = 2

    private let compressor: ImageCompressor
    private let bookmarkStore: OutputDirectoryBookmarkStore
    private let defaults: UserDefaults
    private var processingTask: Task<Void, Never>?
    private var didPromptForInitialFolder = false
    private let desktopPetVisibilityKey = "ImagePet.desktopPetVisible"
    private let outputFormatKey = "ImagePet.outputFormat"
    private let saveLocationModeKey = "ImagePet.saveLocationMode"
    private let filenameSuffixKey = "ImagePet.filenameSuffix"
    private let maxDimensionKey = "ImagePet.maxDimension"
    private let stripMetadataKey = "ImagePet.stripMetadata"

    init(
        compressor: ImageCompressor = ImageCompressor(),
        bookmarkStore: OutputDirectoryBookmarkStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.compressor = compressor
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore ?? OutputDirectoryBookmarkStore(defaults: defaults)
        
        // Default values
        self.outputFormat = .original
        self.saveLocationMode = .designated
        self.filenameSuffix = "_compressed"
        self.maxDimension = .none
        self.stripMetadata = true

        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1" {
            self.isDesktopPetVisible = false
            self.outputDirectory = nil
        } else {
            self.isDesktopPetVisible = defaults.bool(forKey: desktopPetVisibilityKey)
            restoreOutputDirectory()
            
            if let savedFormat = defaults.string(forKey: outputFormatKey), let format = OutputFormat(rawValue: savedFormat) {
                self.outputFormat = format
            }
            if let savedMode = defaults.string(forKey: saveLocationModeKey), let mode = SaveLocationMode(rawValue: savedMode) {
                self.saveLocationMode = mode
            }
            if let savedSuffix = defaults.string(forKey: filenameSuffixKey) {
                self.filenameSuffix = savedSuffix
            }
            if let savedDimension = defaults.string(forKey: maxDimensionKey), let limit = MaxDimensionLimit(rawValue: savedDimension) {
                self.maxDimension = limit
            }
            if defaults.object(forKey: stripMetadataKey) != nil {
                self.stripMetadata = defaults.bool(forKey: stripMetadataKey)
            }
        }
    }

    var completedCount: Int {
        jobs.filter { $0.status == .done || $0.status == .failed || $0.status == .skipped }.count
    }

    var filenamePreview: String {
        let dummyInput = URL(fileURLWithPath: "/tmp/photo.png")
        let targetFormat = outputFormat
        let targetUTType = targetFormat.targetUTType(for: dummyInput)
        let targetExtension = targetUTType.preferredFilenameExtension ?? "png"
        
        let outputName = OutputNameAllocator.outputFileName(
            for: dummyInput,
            suffix: filenameSuffix,
            targetExtension: targetExtension,
            duplicateIndex: 0
        )
        return "photo.png -> \(outputName)"
    }

    func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.title == "ImagePet" || window.identifier?.rawValue == "main" || window.frameAutosaveName == "ImagePet" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    var succeededCount: Int {
        jobs.filter { $0.status == .done }.count
    }

    var failedCount: Int {
        jobs.filter { $0.status == .failed }.count
    }

    var skippedCount: Int {
        jobs.filter { $0.status == .skipped }.count
    }

    var hasFailedJobs: Bool {
        failedCount > 0
    }

    var isCompleted: Bool {
        !jobs.isEmpty && jobs.allSatisfy { $0.status == .done || $0.status == .failed || $0.status == .skipped }
    }

    var successfulOriginalTotal: Int64 {
        jobs
            .filter { $0.status == .done }
            .reduce(Int64(0)) { $0 + $1.originalSize }
    }

    var compressedTotal: Int64 {
        jobs
            .compactMap { $0.status == .done ? $0.compressedSize : nil }
            .reduce(Int64(0), +)
    }

    var savedTotal: Int64 {
        successfulOriginalTotal - compressedTotal
    }

    var savedRatio: Double {
        guard successfulOriginalTotal > 0 else { return 0 }
        return Double(savedTotal) / Double(successfulOriginalTotal)
    }

    func promptForOutputFolderOnFirstLaunch() {
        guard !didPromptForInitialFolder else { return }
        didPromptForInitialFolder = true

        if outputDirectory == nil {
            chooseOutputDirectory()
        }
    }

    func chooseOutputDirectory() {
        guard let url = OutputFolderPanel.chooseFolder() else {
            return
        }

        do {
            try bookmarkStore.save(url)
            outputDirectory = url
            outputFolderMessage = nil
        } catch {
            outputDirectory = nil
            outputFolderMessage = CompressionError.outputFolderUnavailable.localizedDescription
        }
    }

    func chooseInputImages() {
        addInputURLs(InputFilePanel.chooseImages())
    }

    func addDroppedURLs(_ urls: [URL]) {
        addInputURLs(urls)
    }

    private func addInputURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        let newJobs = urls.map { url in
            let size = Self.fileSize(for: url)

            guard SupportedImageFormat.isSupported(url) else {
                return ImageJob(
                    inputURL: url,
                    originalSize: size,
                    status: .failed,
                    errorMessage: CompressionError.unsupportedImageFormat.localizedDescription
                )
            }

            return ImageJob(inputURL: url, originalSize: size)
        }

        jobs.append(contentsOf: newJobs)

        if jobs.contains(where: { $0.status == .pending }) {
            startProcessingIfPossible()
        } else if hasFailedJobs {
            petState = .error
        }
    }

    func retryFailed() {
        guard !isProcessing else { return }

        for index in jobs.indices where jobs[index].status == .failed {
            jobs[index].status = .pending
            jobs[index].outputURL = nil
            jobs[index].compressedSize = nil
            jobs[index].errorMessage = nil
        }

        startProcessingIfPossible()
    }

    func compressMore() {
        guard !isProcessing else { return }

        jobs.removeAll()
        petState = .idle
        outputFolderMessage = nil
        didConfirmOverwrite = false
        Task {
            await compressor.resetReservations()
        }

        if outputDirectory == nil && saveLocationMode == .designated {
            chooseOutputDirectory()
        }
    }

    func revealOutputDirectory() {
        guard let outputDirectory else {
            chooseOutputDirectory()
            return
        }

        NSWorkspace.shared.open(outputDirectory)
    }

    func toggleDesktopPet() {
        isDesktopPetVisible.toggle()
    }

    func showDesktopPet() {
        isDesktopPetVisible = true
    }

    func hideDesktopPet() {
        isDesktopPetVisible = false
    }

    private func restoreOutputDirectory() {
        do {
            outputDirectory = try bookmarkStore.restore()
            outputFolderMessage = nil
        } catch {
            outputDirectory = nil
            outputFolderMessage = CompressionError.outputFolderUnavailable.localizedDescription
        }
    }

    func confirmOverwriteAndStart() {
        showOverwriteConfirmation = false
        didConfirmOverwrite = true
        startProcessingIfPossible()
    }

    func cancelOverwrite() {
        showOverwriteConfirmation = false
        didConfirmOverwrite = false
        failPendingJobs(with: .permissionDenied)
    }

    private func startProcessingIfPossible() {
        guard processingTask == nil else { return }

        if saveLocationMode == .overwrite && !didConfirmOverwrite {
            showOverwriteConfirmation = true
            return
        }

        isProcessing = true
        petState = .eating

        processingTask = Task { [weak self] in
            guard let self = self else { return }

            if self.saveLocationMode == .designated {
                if self.outputDirectory == nil {
                    self.chooseOutputDirectory()
                }
                guard let outputDirectory = self.outputDirectory else {
                    self.failPendingJobs(with: .outputFolderUnavailable)
                    return
                }
                await self.runQueue(outputDirectory: outputDirectory)
            } else if self.saveLocationMode == .originalFolder {
                let hasPermission = await self.checkAndRequestParentFolderPermissions()
                guard hasPermission else {
                    self.failPendingJobs(with: .permissionDenied)
                    return
                }
                await self.runQueue(outputDirectory: nil)
            } else { // overwrite
                await self.runQueue(outputDirectory: nil)
            }
        }
    }

    private func checkAndRequestParentFolderPermissions() async -> Bool {
        let pendingJobs = jobs.filter { $0.status == .pending }
        var unauthorizedFolders: Set<URL> = []
        
        for job in pendingJobs {
            let parentFolder = job.inputURL.deletingLastPathComponent()
            
            if let restoredURL = bookmarkStore.restoreMulti(for: parentFolder) {
                let access = restoredURL.startAccessingSecurityScopedResource()
                let isWritable = FileManager.default.isWritableFile(atPath: parentFolder.path)
                if access {
                    restoredURL.stopAccessingSecurityScopedResource()
                }
                if isWritable {
                    continue
                }
            }
            
            let testURL = parentFolder.appendingPathComponent(".imagepet_sandbox_test_\(UUID().uuidString)")
            do {
                try Data().write(to: testURL)
                try FileManager.default.removeItem(at: testURL)
                try bookmarkStore.saveMulti(parentFolder)
            } catch {
                unauthorizedFolders.insert(parentFolder)
            }
        }
        
        for folder in unauthorizedFolders {
            let success = await showFolderPermissionPanel(for: folder)
            if !success {
                return false
            }
        }
        
        return true
    }

    private func showFolderPermissionPanel(for folder: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.directoryURL = folder
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Authorize"
            panel.message = "ImagePet needs permission to write compressed files to this folder:\n\(folder.path)"
            
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                do {
                    try bookmarkStore.saveMulti(url)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }

    private func runQueue(outputDirectory: URL?) async {
        await withTaskGroup(of: Void.self) { group in
            let workerCount = min(maxConcurrentJobs, max(1, jobs.count))

            for _ in 0..<workerCount {
                group.addTask { [weak self] in
                    while !Task.isCancelled {
                        guard let job = await self?.claimNextPendingJob() else {
                            break
                        }

                        await self?.process(job, outputDirectory: outputDirectory)
                    }
                }
            }
        }

        processingTask = nil

        if jobs.contains(where: { $0.status == .pending }) {
            startProcessingIfPossible()
            return
        }

        isProcessing = false
        petState = hasFailedJobs ? .error : .happy
        didConfirmOverwrite = false
    }

    private func claimNextPendingJob() -> ImageJob? {
        guard let index = jobs.firstIndex(where: { $0.status == .pending }) else {
            return nil
        }

        jobs[index].status = .processing
        jobs[index].errorMessage = nil
        return jobs[index]
    }

    private func process(_ job: ImageJob, outputDirectory: URL?) async {
        let options = CompressionOptions(
            preset: preset,
            format: outputFormat,
            locationMode: saveLocationMode,
            suffix: filenameSuffix,
            maxDimension: maxDimension,
            stripMetadata: stripMetadata
        )

        var targetOutputDir = outputDirectory
        var restoredBookmarkURL: URL? = nil
        
        if saveLocationMode == .originalFolder {
            let parentFolder = job.inputURL.deletingLastPathComponent()
            restoredBookmarkURL = bookmarkStore.restoreMulti(for: parentFolder)
            targetOutputDir = restoredBookmarkURL
        }

        let access = restoredBookmarkURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if access {
                restoredBookmarkURL?.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try await compressor.compress(
                inputURL: job.inputURL,
                outputDirectory: targetOutputDir,
                options: options
            )
            updateJob(job.id) { updated in
                updated.outputURL = result.outputURL
                updated.originalSize = result.originalSize
                updated.compressedSize = result.compressedSize
                updated.status = .done
                updated.errorMessage = nil
            }
        } catch {
            let mapped = CompressionError.map(error)
            updateJob(job.id) { updated in
                if mapped == .skipped {
                    updated.status = .skipped
                    updated.errorMessage = mapped.localizedDescription
                } else {
                    updated.status = .failed
                    updated.errorMessage = mapped.localizedDescription
                }
            }
        }
    }

    private func updateJob(_ id: ImageJob.ID, mutate: (inout ImageJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }

    private func failPendingJobs(with error: CompressionError) {
        for index in jobs.indices where jobs[index].status == .pending {
            jobs[index].status = .failed
            jobs[index].errorMessage = error.localizedDescription
        }

        isProcessing = false
        petState = .error
    }

    private static func fileSize(for url: URL) -> Int64 {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }
}
