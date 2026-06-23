import AppKit
import Foundation
import UserNotifications

protocol NotificationCenterProtocol: AnyObject, Sendable {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func getSettings(completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void)
    func requestAuth(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void)
    func addRequest(_ request: UNNotificationRequest, completionHandler: (@Sendable (Error?) -> Void)?)
    func setCategories(_ categories: Set<UNNotificationCategory>)
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func getSettings(completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        self.getNotificationSettings { settings in
            completionHandler(settings.authorizationStatus)
        }
    }

    func requestAuth(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
        self.requestAuthorization(options: options, completionHandler: completionHandler)
    }

    func addRequest(_ request: UNNotificationRequest, completionHandler: (@Sendable (Error?) -> Void)?) {
        self.add(request, withCompletionHandler: completionHandler)
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        self.setNotificationCategories(categories)
    }
}

enum LocalNotificationAuthorizationState: String {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    init(status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Requested"
        case .denied:
            return "Blocked in System Settings"
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .unknown:
            return "Unknown"
        }
    }

    var canDeliverNotifications: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

enum LocalNotificationAction: String {
    case openImagePet = "OPEN_IMAGEPET"
    case revealInFinder = "REVEAL_IN_FINDER"
    case reviewFailed = "REVIEW_FAILED"
    case openSettings = "OPEN_SETTINGS"
}

final class LocalNotificationManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var authorizationState: LocalNotificationAuthorizationState = .unknown
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: notificationsEnabledKey) }
    }
    @Published var notifyBackgroundCompletion: Bool {
        didSet { defaults.set(notifyBackgroundCompletion, forKey: notifyBackgroundCompletionKey) }
    }
    @Published var notifyAttentionNeeded: Bool {
        didSet { defaults.set(notifyAttentionNeeded, forKey: notifyAttentionNeededKey) }
    }
    @Published var notifyForegroundCompletion: Bool {
        didSet { defaults.set(notifyForegroundCompletion, forKey: notifyForegroundCompletionKey) }
    }
    @Published var notifyFolderWatchingCompletion: Bool {
        didSet { defaults.set(notifyFolderWatchingCompletion, forKey: notifyFolderWatchingCompletionKey) }
    }
    @Published private(set) var lastSummary: CompressionBatchSummary?
    @Published private(set) var recentSummaries: [CompressionBatchSummary] = []
    @Published private(set) var lastDeliveryStatus: String = "No notifications sent yet"

    let notificationAggregationWindow: TimeInterval = 2.0

    private let center: NotificationCenterProtocol
    private let defaults: UserDefaults
    private let notificationsEnabledKey = "ImagePet.notifications.enabled"
    private let notifyBackgroundCompletionKey = "ImagePet.notifications.backgroundCompletion"
    private let notifyAttentionNeededKey = "ImagePet.notifications.attentionNeeded"
    private let notifyForegroundCompletionKey = "ImagePet.notifications.foregroundCompletion"
    private let notifyFolderWatchingCompletionKey = "ImagePet.notifications.folderWatchingCompletion"
    private let recentSummariesKey = "ImagePet.notifications.recentSummaries"
    private let categoryIdentifier = "IMAGEPET_COMPRESSION_SUMMARY"
    private var lastAttentionDeliveryByKey: [String: Date] = [:]
    private var summariesByID: [String: CompressionBatchSummary] = [:]
    private var actionHandler: ((LocalNotificationAction, CompressionBatchSummary?) -> Void)?

    private var pendingFolderWatchSummary: CompressionBatchSummary?
    private var folderWatchDebounceTask: Task<Void, Never>?

    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        self.notificationsEnabled = defaults.object(forKey: notificationsEnabledKey) as? Bool ?? true
        self.notifyBackgroundCompletion = defaults.object(forKey: notifyBackgroundCompletionKey) as? Bool ?? true
        self.notifyAttentionNeeded = defaults.object(forKey: notifyAttentionNeededKey) as? Bool ?? true
        self.notifyForegroundCompletion = defaults.object(forKey: notifyForegroundCompletionKey) as? Bool ?? false
        self.notifyFolderWatchingCompletion = defaults.object(forKey: notifyFolderWatchingCompletionKey) as? Bool ?? false
        
        super.init()
        center.delegate = self
        registerCategories()
        loadAuthorizationStatus()
        loadRecentSummaries()
    }

    @MainActor
    func setActionHandler(_ handler: @escaping (LocalNotificationAction, CompressionBatchSummary?) -> Void) {
        actionHandler = handler
    }

    @MainActor
    func refreshAuthorizationStatus() {
        loadAuthorizationStatus()
    }

    private func loadAuthorizationStatus() {
        center.getSettings { [weak self] status in
            Task { @MainActor in
                self?.authorizationState = LocalNotificationAuthorizationState(status: status)
            }
        }
    }

    private func loadRecentSummaries() {
        if let data = defaults.data(forKey: recentSummariesKey),
           let loaded = try? JSONDecoder().decode([CompressionBatchSummary].self, from: data) {
            recentSummaries = loaded
        }
    }

    private func addToHistory(_ summary: CompressionBatchSummary) {
        var current = recentSummaries
        current.removeAll { $0.id == summary.id }
        current.insert(summary, at: 0)
        if current.count > 20 {
            current = Array(current.prefix(20))
        }
        recentSummaries = current
        saveRecentSummaries()
    }

    private func saveRecentSummaries() {
        if let data = try? JSONEncoder().encode(recentSummaries) {
            defaults.set(data, forKey: recentSummariesKey)
        }
    }

    @MainActor
    func requestAuthorization() {
        center.requestAuth(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshAuthorizationStatus()
            }
        }
    }

    @MainActor
    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    func handleCompletedSummary(_ summary: CompressionBatchSummary, appIsActive: Bool) {
        addToHistory(summary)

        if summary.source == .folderWatching {
            folderWatchDebounceTask?.cancel()

            let merged = pendingFolderWatchSummary?.merging(summary) ?? summary
            pendingFolderWatchSummary = merged
            lastSummary = merged

            folderWatchDebounceTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.notificationAggregationWindow * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if let summaryToDeliver = self.pendingFolderWatchSummary {
                    self.pendingFolderWatchSummary = nil
                    self.deliverSummaryImmediately(summaryToDeliver, appIsActive: appIsActive)
                }
            }
        } else {
            lastSummary = summary
            deliverSummaryImmediately(summary, appIsActive: appIsActive)
        }
    }

    @MainActor
    func deliverSummaryImmediately(_ summary: CompressionBatchSummary, appIsActive: Bool) {
        guard notificationsEnabled else {
            lastDeliveryStatus = "Not delivered: notifications off"
            return
        }

        guard shouldDeliver(summary, appIsActive: appIsActive) else {
            lastDeliveryStatus = "Not delivered: visible in ImagePet"
            return
        }

        guard authorizationState.canDeliverNotifications else {
            lastDeliveryStatus = "Not delivered: notifications \(authorizationState.displayName.lowercased())"
            return
        }

        let content = UNMutableNotificationContent()
        let text = notificationText(for: summary)
        content.title = text.title
        content.body = text.body
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default
        content.userInfo = ["summaryID": summary.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "imagepet.summary.\(summary.id.uuidString)",
            content: content,
            trigger: nil
        )

        summariesByID[summary.id.uuidString] = summary
        center.addRequest(request) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.lastDeliveryStatus = "Not delivered: \(error.localizedDescription)"
                } else {
                    self?.lastDeliveryStatus = "Delivered \(summary.statusText.lowercased()) notification"
                }
            }
        }
    }

    private func shouldDeliver(_ summary: CompressionBatchSummary, appIsActive: Bool) -> Bool {
        if appIsActive && !notifyForegroundCompletion {
            return false
        }

        if summary.source == .shortcuts {
            return summary.requiresUserAction && notifyAttentionNeeded && passesAttentionThrottle(summary)
        }

        if summary.source == .folderWatching {
            if summary.requiresUserAction {
                guard notifyAttentionNeeded else { return false }
                return passesAttentionThrottle(summary)
            }
            return notifyFolderWatchingCompletion
        }

        if summary.requiresUserAction {
            guard notifyAttentionNeeded else { return false }
            return passesAttentionThrottle(summary)
        }

        guard summary.hasSuccesses else {
            return false
        }

        return notifyBackgroundCompletion
    }

    private func passesAttentionThrottle(_ summary: CompressionBatchSummary) -> Bool {
        let key = [
            summary.source.rawValue,
            summary.outputDirectory?.path ?? "no-output",
            summary.primaryErrorMessage ?? "unknown"
        ].joined(separator: "|")

        let now = Date()
        if let lastDelivery = lastAttentionDeliveryByKey[key],
           now.timeIntervalSince(lastDelivery) < 600 {
            return false
        }

        lastAttentionDeliveryByKey[key] = now
        return true
    }

    private func notificationText(for summary: CompressionBatchSummary) -> (title: String, body: String) {
        if summary.hasSuccesses && !summary.hasFailures {
            let noun = summary.successfulCount == 1 ? "image" : "images"
            return (
                "ImagePet finished compressing \(summary.successfulCount) \(noun)",
                "Saved \(FileSizeFormatting.string(from: summary.savedBytes)). Output: \(outputDescription(for: summary))."
            )
        }

        if summary.hasSuccesses && summary.hasFailures {
            return (
                "ImagePet compressed \(summary.successfulCount) of \(summary.totalCount) images",
                "\(summary.failedCount) need attention. Open ImagePet to review."
            )
        }

        if summary.hasFailures {
            return (
                "\(summary.source.displayName) needs attention",
                summary.primaryErrorMessage ?? "Open ImagePet to review failed files."
            )
        }

        return (
            "ImagePet finished",
            "No supported images were compressed."
        )
    }

    private func outputDescription(for summary: CompressionBatchSummary) -> String {
        if summary.outputDirectory != nil {
            return summary.source == .folderWatching ? "Watched destination" : "Output folder"
        }

        if summary.representativeOutputURL != nil {
            return "Original folder"
        }

        return "ImagePet"
    }

    private func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: LocalNotificationAction.openImagePet.rawValue,
            title: "Open ImagePet",
            options: [.foreground]
        )
        let revealAction = UNNotificationAction(
            identifier: LocalNotificationAction.revealInFinder.rawValue,
            title: "Reveal in Finder",
            options: [.foreground]
        )
        let reviewAction = UNNotificationAction(
            identifier: LocalNotificationAction.reviewFailed.rawValue,
            title: "Review Failed",
            options: [.foreground]
        )
        let settingsAction = UNNotificationAction(
            identifier: LocalNotificationAction.openSettings.rawValue,
            title: "Open Settings",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [openAction, revealAction, reviewAction, settingsAction],
            intentIdentifiers: [],
            options: []
        )
        center.setCategories([category])
    }
}

extension LocalNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = LocalNotificationAction(rawValue: response.actionIdentifier) ?? .openImagePet
        let summaryID = response.notification.request.content.userInfo["summaryID"] as? String

        await MainActor.run {
            let summary = summaryID.flatMap { summariesByID[$0] }
            actionHandler?(action, summary)
        }
    }
}

#if DEBUG
enum DebugNotificationType {
    case success
    case failure
    case permission
    case folderWatch
}

extension LocalNotificationManager {
    @MainActor
    func triggerDebugNotification(type: DebugNotificationType) {
        let summary: CompressionBatchSummary
        switch type {
        case .success:
            summary = CompressionBatchSummary(
                source: .manual,
                successfulCount: 3,
                failedCount: 0,
                skippedCount: 0,
                totalInputBytes: 10 * 1024 * 1024,
                totalOutputBytes: 4 * 1024 * 1024,
                outputDirectory: URL(fileURLWithPath: "/tmp"),
                representativeOutputURL: URL(fileURLWithPath: "/tmp/sample.jpg"),
                requiresUserAction: false,
                primaryErrorMessage: nil
            )
        case .failure:
            summary = CompressionBatchSummary(
                source: .manual,
                successfulCount: 2,
                failedCount: 1,
                skippedCount: 0,
                totalInputBytes: 8 * 1024 * 1024,
                totalOutputBytes: 5 * 1024 * 1024,
                outputDirectory: URL(fileURLWithPath: "/tmp"),
                representativeOutputURL: URL(fileURLWithPath: "/tmp/sample.jpg"),
                requiresUserAction: true,
                primaryErrorMessage: "Failed to decode image"
            )
        case .permission:
            summary = CompressionBatchSummary(
                source: .manual,
                successfulCount: 0,
                failedCount: 0,
                skippedCount: 0,
                totalInputBytes: 0,
                totalOutputBytes: 0,
                outputDirectory: nil,
                representativeOutputURL: nil,
                requiresUserAction: true,
                primaryErrorMessage: "Permission denied"
            )
        case .folderWatch:
            summary = CompressionBatchSummary(
                source: .folderWatching,
                successfulCount: 0,
                failedCount: 0,
                skippedCount: 0,
                totalInputBytes: 0,
                totalOutputBytes: 0,
                outputDirectory: nil,
                representativeOutputURL: nil,
                requiresUserAction: true,
                primaryErrorMessage: "Folder watching paused: lost access to folder"
            )
        }

        addToHistory(summary)
        deliverSummaryImmediately(summary, appIsActive: false)
    }
}
#endif
