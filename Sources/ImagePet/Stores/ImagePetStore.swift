import AppKit
import Foundation
import ImagePetCore
import ServiceManagement

enum LaunchMode: String, Codable {
    case normal
    case loginItem
    case fileOpen
    case reopen
}

@MainActor
final class ImagePetStore: ObservableObject {
    @Published var jobs: [ImageJob] = [] {
        didSet {
            checkAndApplyAutoExpand()
            checkIssuesTimeout()
            checkDoneTimeout()
        }
    }
    @Published var preset: CompressionPreset = .balanced {
        didSet {
            defaults.set(preset.rawValue, forKey: presetKey)
            if qualityMode.preset != preset {
                qualityMode = CompressionQualityMode(preset: preset)
            }
        }
    }
    @Published var qualityMode: CompressionQualityMode = .balanced {
        didSet {
            defaults.set(qualityMode.rawValue, forKey: qualityModeKey)
            if let preset = qualityMode.preset, self.preset != preset {
                self.preset = preset
            }
        }
    }
    @Published var customQuality: Int = 80 {
        didSet {
            let clamped = min(95, max(30, customQuality))
            if customQuality != clamped {
                customQuality = clamped
                return
            }
            defaults.set(customQuality, forKey: customQualityKey)
        }
    }
    @Published var outputDirectory: URL? {
        didSet {
            checkAndApplyAutoExpand()
        }
    }
    @Published var petState: PetState = .idle
    @Published var isDropTargeted = false
    @Published var isProcessing = false {
        didSet {
            checkAndApplyAutoExpand()
            resetPetIdleTimer()
        }
    }
    @Published var outputFolderMessage: String? {
        didSet {
            checkAndApplyAutoExpand()
        }
    }
    @Published var selectedMainTab: AppMainTab = .compress
    @Published var selectedSettingsSection: SettingsSection = .desktopPet
    @Published var isDesktopPetEnabled = true {
        didSet {
            defaults.set(isDesktopPetEnabled, forKey: desktopPetEnabledKey)
            guard !isInitializing else { return }
            if !isDesktopPetEnabled {
                isDesktopPetVisible = false
            }
        }
    }
    @Published var isDesktopPetVisible = false {
        didSet {
            defaults.set(isDesktopPetVisible, forKey: desktopPetVisibilityKey)
            guard !isInitializing else { return }
            if isDesktopPetVisible && isDesktopPetEnabled {
                if desktopPetWindowController == nil {
                    desktopPetWindowController = DesktopPetWindowController(store: self)
                }
                let snapshot = petSnapshot
                let isBlocking = snapshot.state == .needsSetup || snapshot.state == .confirm || snapshot.state == .permission
                self.petViewMode = isBlocking ? .full : .mini
            }
            if !isDesktopPetVisible {
                desktopPetWindowController?.setVisible(false)
            } else if isDesktopPetEnabled {
                desktopPetWindowController?.setVisible(true)
            }
        }
    }
    @Published var outputFormat: OutputFormat = .original {
        didSet {
            defaults.set(outputFormat.rawValue, forKey: outputFormatKey)
        }
    }
    @Published var jpegEncodingMode: JPEGEncodingMode = .standard {
        didSet {
            defaults.set(jpegEncodingMode.rawValue, forKey: jpegEncodingModeKey)
        }
    }
    @Published var saveLocationMode: SaveLocationMode = .designated {
        didSet {
            defaults.set(saveLocationMode.rawValue, forKey: saveLocationModeKey)
            if saveLocationMode == .overwrite, outputFormat != .original {
                outputFormat = .original
            }
            checkAndApplyAutoExpand()
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
    @Published var showOverwriteConfirmation = false {
        didSet {
            checkAndApplyAutoExpand()
        }
    }
    var didConfirmOverwrite = false

    @Published var petViewMode: DesktopPetViewMode = .mini {
        didSet {
            defaults.set(petViewMode.rawValue, forKey: petViewModeKey)
            if petViewMode == .full {
                resetPetIdleTimer()
                issuesVisuallyDegraded = false
                doneVisuallyDismissed = false
            } else {
                idleTimerTask?.cancel()
                idleTimerTask = nil
            }
        }
    }

    @Published var enableIdleVariants = true {
        didSet {
            defaults.set(enableIdleVariants, forKey: enableIdleVariantsKey)
        }
    }
    @Published var enableHoverFeedback = true {
        didSet {
            defaults.set(enableHoverFeedback, forKey: enableHoverFeedbackKey)
        }
    }
    @Published var enableSuccessSound = true {
        didSet {
            defaults.set(enableSuccessSound, forKey: enableSuccessSoundKey)
        }
    }
    @Published var energySavingMode = false {
        didSet {
            defaults.set(energySavingMode, forKey: energySavingModeKey)
        }
    }
    @Published var selectedThemeName = "ShibaInu" {
        didSet {
            defaults.set(selectedThemeName, forKey: selectedThemeNameKey)
        }
    }
    @Published var issuesVisuallyDegraded = false
    @Published var doneVisuallyDismissed = false

    // PRD v0.7 Properties
    @Published var launchMode: LaunchMode = .normal
    @Published var launchAtLoginEnabled = false {
        didSet {
            defaults.set(launchAtLoginEnabled, forKey: launchAtLoginKey)
            updateLaunchAtLogin()
        }
    }
    @Published var launchAtLoginError: String? = nil
    @Published var hasReopened = false
    static var shared: ImagePetStore?

    private var isInitializing = true
    private var idleTimerTask: Task<Void, Never>?
    private var issuesTimer: Timer?
    private var doneTimer: Timer?

    let maxConcurrentJobs = 2

    private let compressor: ImageCompressor
    private let encoderCapabilities: EncoderCapabilities
    private let bookmarkStore: OutputDirectoryBookmarkStore
    private let defaults: UserDefaults
    private var processingTask: Task<Void, Never>?
    private var openMainWindow: (() -> Void)?
    private var openHelpWindow: (() -> Void)?
    private var desktopPetWindowController: DesktopPetWindowController?
    private var isPetHovering = false
    private var didPromptForInitialFolder = false

    @Published public var folderWatchManager: FolderWatchManager!

    private let desktopPetVisibilityKey = "ImagePet.desktopPetVisible"
    private let outputFormatKey = "ImagePet.outputFormat"
    private let jpegEncodingModeKey = "ImagePet.jpegEncodingMode"
    private let presetKey = "ImagePet.preset"
    private let qualityModeKey = "ImagePet.qualityMode"
    private let customQualityKey = "ImagePet.customQuality"
    private let saveLocationModeKey = "ImagePet.saveLocationMode"
    private let filenameSuffixKey = "ImagePet.filenameSuffix"
    private let maxDimensionKey = "ImagePet.maxDimension"
    private let stripMetadataKey = "ImagePet.stripMetadata"
    private let enableIdleVariantsKey = "ImagePet.enableIdleVariants"
    private let enableHoverFeedbackKey = "ImagePet.enableHoverFeedback"
    private let enableSuccessSoundKey = "ImagePet.enableSuccessSound"
    private let energySavingModeKey = "ImagePet.energySavingMode"
    private let selectedThemeNameKey = "ImagePet.selectedThemeName"

    // PRD v0.7 Keys
    private let launchAtLoginKey = "ImagePet.launchAtLogin"
    private let desktopPetEnabledKey = "ImagePet.desktopPetEnabled"
    private let petViewModeKey = "ImagePet.petViewMode"

    init(
        compressor: ImageCompressor? = nil,
        encoderCapabilities: EncoderCapabilities = .current,
        bookmarkStore: OutputDirectoryBookmarkStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.encoderCapabilities = encoderCapabilities
        self.compressor = compressor ?? ImageCompressor(capabilities: encoderCapabilities)
        self.defaults = defaults
        self.bookmarkStore = bookmarkStore ?? OutputDirectoryBookmarkStore(defaults: defaults)

        self.outputFormat = .original
        self.jpegEncodingMode = .standard
        self.saveLocationMode = .designated
        self.filenameSuffix = "_compressed"
        self.maxDimension = .none
        self.stripMetadata = true
        self.qualityMode = .balanced
        self.customQuality = 80
        self.petViewMode = .mini

        self.enableIdleVariants = true
        self.enableHoverFeedback = true
        self.enableSuccessSound = true
        self.energySavingMode = false
        self.selectedThemeName = "ShibaInu"

        self.isDesktopPetEnabled = true
        self.launchAtLoginEnabled = false
        ImagePetStore.shared = self

        self.folderWatchManager = FolderWatchManager(defaults: defaults)
        self.folderWatchManager.store = self

        let isUITesting = ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1"
        let isRestorationTesting = ProcessInfo.processInfo.environment["IS_UI_TESTING_RESTORATION"] == "1"

        // 1. 推断或注入 LaunchMode
        if let envModeString = ProcessInfo.processInfo.environment["IMAGEPET_LAUNCH_MODE"],
           let envMode = LaunchMode(rawValue: envModeString) {
            self.launchMode = envMode
        } else {
            let isBackgroundLaunch = !NSApplication.shared.isActive
            let launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
            if isBackgroundLaunch && launchAtLogin && !isRestorationTesting && !isUITesting {
                self.launchMode = .loginItem
            } else {
                self.launchMode = .normal
            }
        }

        if isUITesting && !isRestorationTesting {
            if let mockEnabled = ProcessInfo.processInfo.environment["IMAGEPET_MOCK_PET_ENABLED"] {
                self.isDesktopPetEnabled = (mockEnabled != "0")
            } else {
                self.isDesktopPetEnabled = true
            }
            if let mockVisible = ProcessInfo.processInfo.environment["IMAGEPET_MOCK_PET_VISIBLE"] {
                self.isDesktopPetVisible = (mockVisible == "1")
            } else {
                self.isDesktopPetVisible = false
            }
            if self.launchMode == .loginItem {
                self.outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            } else {
                self.outputDirectory = nil
            }
            self.petViewMode = .mini
            self.enableSuccessSound = true
            self.preset = .balanced
            self.qualityMode = .balanced
            self.customQuality = 80
            self.jpegEncodingMode = .standard
            if ProcessInfo.processInfo.environment["UI_TEST_OVERWRITE"] == "1" {
                self.saveLocationMode = .overwrite
            }
            self.launchAtLoginEnabled = false
        } else {
            if defaults.object(forKey: desktopPetEnabledKey) == nil {
                self.isDesktopPetEnabled = true
            } else {
                self.isDesktopPetEnabled = defaults.bool(forKey: desktopPetEnabledKey)
            }
            self.isDesktopPetVisible = defaults.bool(forKey: desktopPetVisibilityKey)
            restoreOutputDirectory()

            if let savedFormat = defaults.string(forKey: outputFormatKey), let format = OutputFormat(rawValue: savedFormat) {
                self.outputFormat = encoderCapabilities.writableFormats.contains(format) ? format : .original
            }
            if let savedJPEGMode = defaults.string(forKey: jpegEncodingModeKey),
               let mode = JPEGEncodingMode(rawValue: savedJPEGMode) {
                self.jpegEncodingMode = encoderCapabilities.jpegEncodingModes.contains(mode) ? mode : .standard
            }
            if let savedPreset = defaults.string(forKey: presetKey), let preset = CompressionPreset(rawValue: savedPreset) {
                self.preset = preset
                self.qualityMode = CompressionQualityMode(preset: preset)
            }
            if let savedQualityMode = defaults.string(forKey: qualityModeKey), let mode = CompressionQualityMode(rawValue: savedQualityMode) {
                self.qualityMode = mode
            }
            if defaults.object(forKey: customQualityKey) != nil {
                self.customQuality = min(95, max(30, defaults.integer(forKey: customQualityKey)))
            }
            if let savedMode = defaults.string(forKey: saveLocationModeKey), let mode = SaveLocationMode(rawValue: savedMode) {
                self.saveLocationMode = mode
            }
            if self.saveLocationMode == .overwrite {
                self.outputFormat = .original
            }
            if let savedSuffix = defaults.string(forKey: filenameSuffixKey) {
                self.filenameSuffix = OutputNameAllocator.sanitizedSuffix(savedSuffix)
            }
            if let savedDimension = defaults.string(forKey: maxDimensionKey), let limit = MaxDimensionLimit(rawValue: savedDimension) {
                self.maxDimension = limit
            }
            if defaults.object(forKey: stripMetadataKey) != nil {
                self.stripMetadata = defaults.bool(forKey: stripMetadataKey)
            }

            if defaults.object(forKey: enableIdleVariantsKey) != nil {
                self.enableIdleVariants = defaults.bool(forKey: enableIdleVariantsKey)
            }
            if defaults.object(forKey: enableHoverFeedbackKey) != nil {
                self.enableHoverFeedback = defaults.bool(forKey: enableHoverFeedbackKey)
            }
            if defaults.object(forKey: enableSuccessSoundKey) != nil {
                self.enableSuccessSound = defaults.bool(forKey: enableSuccessSoundKey)
            }
            if defaults.object(forKey: energySavingModeKey) != nil {
                self.energySavingMode = defaults.bool(forKey: energySavingModeKey)
            }
            if let theme = defaults.string(forKey: selectedThemeNameKey) {
                self.selectedThemeName = theme
            }

            if defaults.object(forKey: launchAtLoginKey) != nil {
                self.launchAtLoginEnabled = defaults.bool(forKey: launchAtLoginKey)
            } else {
                if #available(macOS 13.0, *) {
                    self.launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
                }
            }

            if let savedMode = defaults.string(forKey: petViewModeKey), let mode = DesktopPetViewMode(rawValue: savedMode) {
                self.petViewMode = mode
            } else {
                self.petViewMode = .mini
            }
        }

        if isUITesting && isRestorationTesting {
            if let mockEnabled = ProcessInfo.processInfo.environment["IMAGEPET_MOCK_PET_ENABLED"] {
                self.isDesktopPetEnabled = (mockEnabled != "0")
            }
            if let mockVisible = ProcessInfo.processInfo.environment["IMAGEPET_MOCK_PET_VISIBLE"] {
                self.isDesktopPetVisible = (mockVisible == "1")
            }
        }

        checkAndApplyAutoExpand()
        self.isInitializing = false
    }

    var completedCount: Int {
        jobs.filter { $0.status == .done || $0.status == .failed || $0.status == .skipped }.count
    }

    var availableOutputFormats: [OutputFormat] {
        OutputFormat.allCases.filter { encoderCapabilities.writableFormats.contains($0) }
    }

    var qualitySummary: String {
        guard outputFormat != .png else {
            return "Lossless"
        }
        return qualityMode.compressionQuality(customQuality: customQuality).displayName
    }

    var effectiveLossyQuality: CompressionQuality? {
        outputFormat == .png ? nil : qualityMode.compressionQuality(customQuality: customQuality)
    }

    var canUseAdvancedJPEG: Bool {
        guard encoderCapabilities.jpegEncodingModes.contains(.advanced),
              saveLocationMode != .overwrite else {
            return false
        }

        if outputFormat == .jpeg {
            return true
        }

        if outputFormat == .original {
            return jobs.contains { SupportedImageFormat.format(for: $0.inputURL) == .jpeg }
        }

        return false
    }

    var effectiveJPEGEncodingMode: JPEGEncodingMode {
        canUseAdvancedJPEG ? jpegEncodingMode : .standard
    }

    var filenamePreview: String {
        let dummyInput = URL(fileURLWithPath: "/tmp/photo.png")
        let targetFormat = encoderCapabilities.writableFormats.contains(outputFormat) ? outputFormat : .original
        let targetExtension = targetFormat.targetExtension(for: dummyInput)

        let outputName = OutputNameAllocator.outputFileName(
            for: dummyInput,
            suffix: filenameSuffix,
            targetExtension: targetExtension,
            duplicateIndex: 0
        )
        return "photo.png -> \(outputName)"
    }

    func sanitizeFilenameSuffix() {
        let sanitized = OutputNameAllocator.sanitizedSuffix(filenameSuffix)
        if filenameSuffix != sanitized {
            filenameSuffix = sanitized
        }
    }

    func setMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
    }

    func setHelpWindowOpener(_ opener: @escaping () -> Void) {
        openHelpWindow = opener
    }

    func openHelp() {
        openHelpWindow?()
    }

    func showSettings(_ section: SettingsSection) {
        selectedSettingsSection = section
        selectedMainTab = .settings
        activateMainWindow()
    }

    func activateMainWindow() {
        self.hasReopened = true
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        if focusMainWindowIfPresent() {
            return
        }

        openMainWindow?()

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            if self.focusMainWindowIfPresent() {
                return
            }

            self.openMainWindow?()
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.focusMainWindowIfPresent()
        }
    }

    @discardableResult
    private func focusMainWindowIfPresent() -> Bool {
        for window in NSApp.windows {
            guard window.isVisible else {
                continue
            }

            if window.title == "ImagePet" || window.identifier?.rawValue == "main" || window.frameAutosaveName == "ImagePet" {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return false
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
        guard saveLocationMode == .designated else { return }
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
        let urls = InputFilePanel.chooseImages()
        addInputURLs(urls)
    }

    func addDroppedURLs(_ urls: [URL]) {
        addInputURLs(urls)
    }

    private func addInputURLs(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let newJobs = urls.map { url in
            let size = Self.fileSize(for: url)

            guard SupportedImageFormat.isSupported(url, capabilities: encoderCapabilities) else {
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

    func processWatchedFiles(_ urls: [URL], outputDirectory: URL) {
        guard !urls.isEmpty else { return }

        let newJobs = urls.map { url in
            let size = Self.fileSize(for: url)

            guard SupportedImageFormat.isSupported(url, capabilities: encoderCapabilities) else {
                return ImageJob(
                    inputURL: url,
                    originalSize: size,
                    status: .failed,
                    errorMessage: CompressionError.unsupportedImageFormat.localizedDescription,
                    designatedOutputDirectory: outputDirectory
                )
            }

            return ImageJob(
                inputURL: url,
                originalSize: size,
                designatedOutputDirectory: outputDirectory
            )
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

        clearDoneTimeout()
        clearIssuesTimeout()
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
        if saveLocationMode == .designated {
            guard let outputDirectory else {
                chooseOutputDirectory()
                return
            }
            NSWorkspace.shared.open(outputDirectory)
        } else {
            if let firstSuccess = jobs.first(where: { $0.status == .done && $0.outputURL != nil }),
               let outputURL = firstSuccess.outputURL {
                let parentDir = outputURL.deletingLastPathComponent()
                NSWorkspace.shared.open(parentDir)
            } else if let outputDirectory {
                NSWorkspace.shared.open(outputDirectory)
            }
        }
    }

    var petSnapshot: DesktopPetSnapshot {
        if saveLocationMode == .designated && outputDirectory == nil {
            return DesktopPetSnapshot(
                state: .needsSetup,
                title: "Needs folder",
                detail: "Choose output folder in app",
                primaryAction: .openMainApp,
                secondaryActions: [.hidePet],
                canAcceptDrop: false
            )
        }

        if saveLocationMode == .overwrite && showOverwriteConfirmation {
            return DesktopPetSnapshot(
                state: .confirm,
                title: "Confirm overwrite",
                detail: "Review in app",
                primaryAction: .openMainApp,
                secondaryActions: [.hidePet],
                canAcceptDrop: false
            )
        }

        let hasPermissionDenied = jobs.contains { $0.status == .failed && $0.errorMessage == CompressionError.permissionDenied.localizedDescription }
        let hasFolderDenied = outputFolderMessage == CompressionError.permissionDenied.localizedDescription
        if hasPermissionDenied || hasFolderDenied {
            return DesktopPetSnapshot(
                state: .permission,
                title: "Permission needed",
                detail: "Open app to authorize",
                primaryAction: .openMainApp,
                secondaryActions: [.hidePet],
                canAcceptDrop: false
            )
        }

        if isProcessing {
            return DesktopPetSnapshot(
                state: .eating,
                title: "Eating",
                detail: "\(completedCount) / \(jobs.count)",
                primaryAction: nil,
                secondaryActions: [.addImages, .hidePet],
                canAcceptDrop: true
            )
        }

        if isCompleted {
            if failedCount == 0 {
                let hasSuccess = jobs.contains { $0.status == .done }
                let secondary: [DesktopPetAction]
                if hasSuccess {
                    secondary = [.addImages, .revealOutput, .compressMore, .hidePet]
                } else {
                    secondary = [.addImages, .compressMore, .hidePet]
                }
                return DesktopPetSnapshot(
                    state: doneVisuallyDismissed ? .idle : .done,
                    title: doneVisuallyDismissed ? "Ready" : "Done",
                    detail: "Saved \(FileSizeFormatting.string(from: savedTotal))",
                    primaryAction: hasSuccess ? .revealOutput : .addImages,
                    secondaryActions: secondary,
                    canAcceptDrop: true
                )
            } else {
                let detailText: String
                if skippedCount > 0 {
                    detailText = "\(succeededCount) ok, \(skippedCount) skip, \(failedCount) fail"
                } else {
                    detailText = "\(succeededCount) ok, \(failedCount) fail"
                }
                return DesktopPetSnapshot(
                    state: .issues,
                    title: "Issues",
                    detail: detailText,
                    primaryAction: .retryFailed,
                    secondaryActions: [.addImages, .retryFailed, .compressMore, .hidePet],
                    canAcceptDrop: true
                )
            }
        }

        return DesktopPetSnapshot(
            state: .idle,
            title: "Ready",
            detail: "Drop images here",
            primaryAction: .addImages,
            secondaryActions: [.addImages, .hidePet],
            canAcceptDrop: true
        )
    }

    func handlePetAction(_ action: DesktopPetAction) {
        switch action {
        case .openMainApp:
            activateMainWindow()
        case .hidePet:
            hideDesktopPet()
        case .addImages:
            activateMainWindow()
            Task { @MainActor in
                await Task.yield()
                chooseInputImages()
            }
        case .revealOutput:
            revealOutputDirectory()
        case .retryFailed:
            retryFailed()
        case .compressMore:
            compressMore()
        case .expand:
            petViewMode = .full
        case .collapse:
            NotificationCenter.default.post(name: .desktopPetWillCollapse, object: nil)
        }
        resetPetIdleTimer()
    }

    func performCollapse() {
        self.petViewMode = .mini
    }

    func toggleDesktopPet() {
        isDesktopPetVisible.toggle()
    }

    func toggleDesktopPetMode() {
        guard isDesktopPetEnabled else {
            return
        }

        guard isDesktopPetVisible else {
            isDesktopPetVisible = true
            petViewMode = .mini
            return
        }

        if petViewMode == .full {
            handlePetAction(.collapse)
        } else {
            petViewMode = .full
        }
    }

    func attachDesktopPetControllerIfNeeded() {
        if desktopPetWindowController == nil {
            desktopPetWindowController = DesktopPetWindowController(store: self)
        }
        desktopPetWindowController?.setVisible(isDesktopPetVisible)
    }

    func showDesktopPet() {
        isDesktopPetVisible = true
    }

    func hideDesktopPet() {
        isPetHovering = false
        isDesktopPetVisible = false
    }

    func setPetHovering(_ isHovering: Bool) {
        guard isPetHovering != isHovering else { return }
        isPetHovering = isHovering

        if isHovering {
            idleTimerTask?.cancel()
            idleTimerTask = nil
        } else {
            resetPetIdleTimer()
        }
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
        failPendingJobs(message: "Canceled")
    }

    private func startProcessingIfPossible() {
        guard processingTask == nil else {
            return
        }

        if saveLocationMode == .overwrite && !didConfirmOverwrite {
            activateMainWindow()
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
            if response == .OK,
               let url = panel.url,
               isAuthorizedFolderSelection(url, for: folder) {
                do {
                    try bookmarkStore.saveMulti(url, for: folder)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }

    private func isAuthorizedFolderSelection(_ selectedURL: URL, for requestedFolder: URL) -> Bool {
        let selectedComponents = selectedURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents
        let requestedComponents = requestedFolder
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents

        guard selectedComponents.count <= requestedComponents.count else {
            return false
        }

        return zip(selectedComponents, requestedComponents).allSatisfy(==)
    }

    private func runQueue(outputDirectory: URL?) async {
        let batchJobIDs = Set(jobs.filter { $0.status == .pending }.map { $0.id })

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

        let processedJobs = jobs.filter { batchJobIDs.contains($0.id) }
        let batchHasFailures = processedJobs.contains { $0.status == .failed }
        let batchHasSuccess = processedJobs.contains { $0.status == .done }

        if !batchHasFailures && batchHasSuccess && enableSuccessSound {
            SoundManager.shared.playSuccessSound()
        }
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
        let compressionOptions = CompressionOptions(
            lossyQuality: effectiveLossyQuality,
            format: outputFormat,
            jpegEncodingMode: effectiveJPEGEncodingMode,
            maxDimension: maxDimension,
            stripMetadata: stripMetadata
        )
        let saveOptions = SaveOptions(
            locationMode: saveLocationMode,
            suffix: OutputNameAllocator.sanitizedSuffix(filenameSuffix)
        )

        var targetOutputDir = outputDirectory
        var restoredBookmarkURL: URL? = nil

        if let designated = job.designatedOutputDirectory {
            targetOutputDir = designated
            // Make sure we have access to the designated output folder (handled by FolderWatchManager's bookmark resolving implicitly, but we can do it explicitly)
            // It's actually already startAccessingSecurityScopedResource'd by FolderWatchManager when it resolved the outputURL
        } else if saveLocationMode == .originalFolder {
            let parentFolder = job.inputURL.deletingLastPathComponent()
            restoredBookmarkURL = bookmarkStore.restoreMulti(for: parentFolder)
            targetOutputDir = parentFolder
        }

        let access = restoredBookmarkURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if access {
                restoredBookmarkURL?.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let environment = ProcessInfo.processInfo.environment
            if environment["IS_UI_TESTING"] == "1", environment["UI_TEST_SLOW_PROCESS"] == "1" {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            let result = try await compressor.compress(
                inputURL: job.inputURL,
                outputDirectory: targetOutputDir,
                compressionOptions: compressionOptions,
                saveOptions: saveOptions
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
                if mapped.isSkippedResult {
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
        failPendingJobs(message: error.localizedDescription)
    }

    private func failPendingJobs(message: String) {
        for index in jobs.indices where jobs[index].status == .pending {
            jobs[index].status = .failed
            jobs[index].errorMessage = message
        }

        processingTask = nil
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

    func checkAndApplyAutoExpand() {
        let snapshot = petSnapshot
        if snapshot.state == .needsSetup || snapshot.state == .confirm || snapshot.state == .permission {
            self.petViewMode = .full
        }
        if isCompleted && failedCount == jobs.count && jobs.count > 0 {
            self.petViewMode = .full
        }
    }

    func resetPetIdleTimer() {
        idleTimerTask?.cancel()

        guard petViewMode == .full else { return }

        let snapshot = petSnapshot
        let isBlocking = snapshot.state == .needsSetup || snapshot.state == .confirm || snapshot.state == .permission
        guard !isBlocking && !isProcessing else { return }
        guard !isPetHovering else { return }

        idleTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            guard !Task.isCancelled else { return }
            self?.handlePetAction(.collapse)
        }
    }

    private func checkIssuesTimeout() {
        let isCurrentlyIssues = isCompleted && failedCount > 0
        if isCurrentlyIssues {
            if issuesTimer == nil && !issuesVisuallyDegraded {
                let isTesting = ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1" || NSClassFromString("XCTestCase") != nil
                let interval: TimeInterval = isTesting ? 2.0 : 600.0

                issuesTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if self.isCompleted && self.failedCount > 0 {
                            self.issuesVisuallyDegraded = true
                        }
                    }
                }
            }
        } else {
            clearIssuesTimeout()
        }
    }

    private func clearIssuesTimeout() {
        issuesTimer?.invalidate()
        issuesTimer = nil
        issuesVisuallyDegraded = false
    }

    private func checkDoneTimeout() {
        let isCurrentlyDone = isCompleted && failedCount == 0 && jobs.count > 0
        if isCurrentlyDone {
            if doneTimer == nil && !doneVisuallyDismissed {
                let interval: TimeInterval = 3.5

                doneTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if self.isCompleted && self.failedCount == 0 {
                            self.doneVisuallyDismissed = true
                        }
                    }
                }
            }
        } else {
            clearDoneTimeout()
        }
    }

    private func clearDoneTimeout() {
        doneTimer?.invalidate()
        doneTimer = nil
        doneVisuallyDismissed = false
    }

    private func updateLaunchAtLogin() {
        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "1" {
            return
        }
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if launchAtLoginEnabled {
                if service.status == .enabled { return }
                do {
                    launchAtLoginError = nil
                    try service.register()
                } catch {
                    launchAtLoginError = "Failed to enable launch at login: \(error.localizedDescription)"
                    launchAtLoginEnabled = false
                    #if DEBUG
                    print("[ImagePetStore] Error registering launch service: \(error)")
                    #endif
                }
            } else {
                if service.status == .notRegistered { return }
                do {
                    launchAtLoginError = nil
                    try service.unregister()
                } catch {
                    launchAtLoginError = "Failed to disable launch at login: \(error.localizedDescription)"
                    launchAtLoginEnabled = true
                    #if DEBUG
                    print("[ImagePetStore] Error unregistering launch service: \(error)")
                    #endif
                }
            }
        }
    }
}

extension Notification.Name {
    static let desktopPetWillCollapse = Notification.Name("ImagePet.desktopPetWillCollapse")
}
