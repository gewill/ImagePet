import Foundation

public enum FolderMonitorError: Error, LocalizedError {
    case cannotAccessDirectory
    case failedToStartMonitor

    public var errorDescription: String? {
        switch self {
        case .cannotAccessDirectory:
            return "Cannot access the specified directory. Please check permissions."
        case .failedToStartMonitor:
            return "Failed to start monitoring the directory."
        }
    }
}

public protocol FolderMonitorDelegate: AnyObject {
    func folderMonitor(_ monitor: FolderMonitor, didDiscoverNewFiles files: [URL])
    func folderMonitor(_ monitor: FolderMonitor, didEncounterError error: Error)
}

public class FolderMonitor {
    public let monitoredURL: URL
    public weak var delegate: FolderMonitorDelegate?

    private var source: DispatchSourceFileSystemObject?
    private let monitorQueue = DispatchQueue(label: "com.imagepet.foldermonitor", qos: .background)
    private var knownFiles: Set<URL> = []

    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 0.8
    private var pendingFiles: Set<URL> = []

    private var isAccessingSecurityScopedResource = false

    public init(url: URL) {
        self.monitoredURL = url
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard source == nil else { return }

        let hasAccess = monitoredURL.startAccessingSecurityScopedResource()
        isAccessingSecurityScopedResource = hasAccess

        let fileDescriptor = open(monitoredURL.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            if isAccessingSecurityScopedResource {
                monitoredURL.stopAccessingSecurityScopedResource()
                isAccessingSecurityScopedResource = false
            }
            throw FolderMonitorError.cannotAccessDirectory
        }

        // Populate initial known files so we don't process existing ones
        updateKnownFiles()

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: monitorQueue
        )

        source?.setEventHandler { [weak self] in
            self?.directoryDidChange()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil

        debounceTimer?.cancel()
        debounceTimer = nil

        if isAccessingSecurityScopedResource {
            monitoredURL.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
        }
    }

    private func directoryDidChange() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: monitoredURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let currentFiles = Set(contents)

            let newFiles = currentFiles.subtracting(knownFiles)

            if !newFiles.isEmpty {
                knownFiles.formUnion(newFiles)
                pendingFiles.formUnion(newFiles)
                scheduleDebounceTimer()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.folderMonitor(self, didEncounterError: error)
            }
        }
    }

    private func scheduleDebounceTimer() {
        debounceTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            self?.processPendingFiles()
        }
        timer.resume()
        debounceTimer = timer
    }

    private func processPendingFiles() {
        let filesToProcess = Array(pendingFiles)
        pendingFiles.removeAll()

        guard !filesToProcess.isEmpty else { return }

        // Further filter out directories and unsupported types if needed,
        // but ImagePetCore should handle unsupported formats gracefully.
        // We'll just pass files to the delegate.
        let fileURLs = filesToProcess.filter { !$0.hasDirectoryPath }

        if !fileURLs.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.folderMonitor(self, didDiscoverNewFiles: fileURLs)
            }
        }
    }

    private func updateKnownFiles() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: monitoredURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            knownFiles = Set(contents)
        } catch {
            print("FolderMonitor: Failed to list initial directory contents for \(monitoredURL.path)")
        }
    }
}
