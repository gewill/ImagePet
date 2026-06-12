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

    let maxConcurrentJobs = 2

    private let compressor: ImageCompressor
    private let bookmarkStore: OutputDirectoryBookmarkStore
    private let defaults: UserDefaults
    private var processingTask: Task<Void, Never>?
    private var didPromptForInitialFolder = false
    private let desktopPetVisibilityKey = "ImagePet.desktopPetVisible"

    init(
        compressor: ImageCompressor = ImageCompressor(),
        bookmarkStore: OutputDirectoryBookmarkStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.compressor = compressor
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore ?? OutputDirectoryBookmarkStore(defaults: defaults)
        self.isDesktopPetVisible = defaults.bool(forKey: desktopPetVisibilityKey)
        restoreOutputDirectory()
    }

    var completedCount: Int {
        jobs.filter { $0.status == .done || $0.status == .failed }.count
    }

    var succeededCount: Int {
        jobs.filter { $0.status == .done }.count
    }

    var failedCount: Int {
        jobs.filter { $0.status == .failed }.count
    }

    var hasFailedJobs: Bool {
        failedCount > 0
    }

    var isCompleted: Bool {
        !jobs.isEmpty && jobs.allSatisfy { $0.status == .done || $0.status == .failed }
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
        Task {
            await compressor.resetReservations()
        }

        if outputDirectory == nil {
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

    private func startProcessingIfPossible() {
        guard processingTask == nil else { return }

        if outputDirectory == nil {
            chooseOutputDirectory()
        }

        guard let outputDirectory else {
            failPendingJobs(with: .outputFolderUnavailable)
            return
        }

        isProcessing = true
        petState = .eating

        processingTask = Task { [weak self] in
            await self?.runQueue(outputDirectory: outputDirectory)
        }
    }

    private func runQueue(outputDirectory: URL) async {
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
    }

    private func claimNextPendingJob() -> ImageJob? {
        guard let index = jobs.firstIndex(where: { $0.status == .pending }) else {
            return nil
        }

        jobs[index].status = .processing
        jobs[index].errorMessage = nil
        return jobs[index]
    }

    private func process(_ job: ImageJob, outputDirectory: URL) async {
        do {
            let result = try await compressor.compress(
                inputURL: job.inputURL,
                outputDirectory: outputDirectory,
                preset: preset
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
                updated.status = .failed
                updated.errorMessage = mapped.localizedDescription
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
