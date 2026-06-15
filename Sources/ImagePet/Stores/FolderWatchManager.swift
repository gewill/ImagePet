import Foundation
import SwiftUI
import AppKit

struct FolderWatchTask: Identifiable, Codable, Equatable {
    let id: UUID
    let sourceBookmark: Data
    let outputBookmark: Data

    init(id: UUID = UUID(), sourceBookmark: Data, outputBookmark: Data) {
        self.id = id
        self.sourceBookmark = sourceBookmark
        self.outputBookmark = outputBookmark
    }
}

@MainActor
final class FolderWatchManager: ObservableObject {
    @Published var tasks: [FolderWatchTask] = []

    // We map task ID to active FolderMonitor instance
    private var activeMonitors: [UUID: FolderMonitor] = [:]

    // For storing task data
    private let tasksKey = "ImagePet.FolderWatchTasks"
    private let defaults: UserDefaults

    // We need to resolve bookmarks to URLs when UI needs to show them
    @Published var resolvedSourceURLs: [UUID: URL] = [:]
    @Published var resolvedOutputURLs: [UUID: URL] = [:]

    weak var store: ImagePetStore?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadTasks()
    }

    private func loadTasks() {
        guard let data = defaults.data(forKey: tasksKey),
              let loadedTasks = try? JSONDecoder().decode([FolderWatchTask].self, from: data) else {
            return
        }

        self.tasks = loadedTasks

        // Resolve URLs and start monitors
        for task in loadedTasks {
            startTask(task)
        }
    }

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: tasksKey)
        }
    }

    func addTask(sourceURL: URL, outputURL: URL) throws {
        // Create security scoped bookmarks
        let sourceBookmark = try sourceURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let outputBookmark = try outputURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

        let task = FolderWatchTask(sourceBookmark: sourceBookmark, outputBookmark: outputBookmark)
        tasks.append(task)
        saveTasks()
        startTask(task)
    }

    func removeTask(id: UUID) {
        stopTask(id: id)
        tasks.removeAll { $0.id == id }
        resolvedSourceURLs.removeValue(forKey: id)
        resolvedOutputURLs.removeValue(forKey: id)
        saveTasks()
    }

    private func startTask(_ task: FolderWatchTask) {
        var sourceIsStale = false
        var outputIsStale = false

        guard let sourceURL = try? URL(resolvingBookmarkData: task.sourceBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &sourceIsStale),
              let outputURL = try? URL(resolvingBookmarkData: task.outputBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &outputIsStale) else {
            print("FolderWatchManager: Failed to resolve bookmarks for task \(task.id)")
            notifyError("Folder watching paused: failed to resolve folder permission bookmarks.")
            return
        }

        resolvedSourceURLs[task.id] = sourceURL
        resolvedOutputURLs[task.id] = outputURL

        let monitor = FolderMonitor(url: sourceURL)
        monitor.delegate = self

        do {
            try monitor.start()
            activeMonitors[task.id] = monitor
        } catch {
            print("FolderWatchManager: Failed to start monitor for \(sourceURL.path): \(error)")
            notifyError("Folder watching paused: failed to start monitor for \(sourceURL.lastPathComponent). \(error.localizedDescription)", directory: sourceURL)
        }
    }

    private func stopTask(id: UUID) {
        if let monitor = activeMonitors[id] {
            monitor.stop()
            activeMonitors.removeValue(forKey: id)
        }
    }

    private func notifyError(_ message: String, directory: URL? = nil) {
        let summary = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 0,
            failedCount: 0,
            skippedCount: 0,
            totalInputBytes: 0,
            totalOutputBytes: 0,
            outputDirectory: directory,
            representativeOutputURL: nil,
            requiresUserAction: true,
            primaryErrorMessage: message
        )
        store?.notificationManager.handleCompletedSummary(summary, appIsActive: NSApp.isActive)
    }
}

extension FolderWatchManager: FolderMonitorDelegate {
    nonisolated func folderMonitor(_ monitor: FolderMonitor, didDiscoverNewFiles files: [URL]) {
        let monitorID = ObjectIdentifier(monitor)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Find which task this monitor belongs to
            guard let (taskId, _) = self.activeMonitors.first(where: { ObjectIdentifier($1) == monitorID }),
                  let outputURL = self.resolvedOutputURLs[taskId] else {
                return
            }

            // Send files to the store to compress
            self.store?.processWatchedFiles(files, outputDirectory: outputURL)
        }
    }

    nonisolated func folderMonitor(_ monitor: FolderMonitor, didEncounterError error: Error) {
        print("FolderMonitor error: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.notifyError("Folder watching error: \(error.localizedDescription)", directory: monitor.monitoredURL)
        }
    }
}
