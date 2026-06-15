import AppKit
import Foundation
import UserNotifications

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
            return "Not Enabled"
        case .denied:
            return "Denied"
        case .authorized:
            return "Enabled"
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
    @Published var notifyBackgroundCompletion: Bool {
        didSet { defaults.set(notifyBackgroundCompletion, forKey: notifyBackgroundCompletionKey) }
    }
    @Published var notifyAttentionNeeded: Bool {
        didSet { defaults.set(notifyAttentionNeeded, forKey: notifyAttentionNeededKey) }
    }
    @Published var notifyForegroundCompletion: Bool {
        didSet { defaults.set(notifyForegroundCompletion, forKey: notifyForegroundCompletionKey) }
    }
    @Published private(set) var lastSummary: BackgroundCompressionSummary?
    @Published private(set) var lastDeliveryStatus: String = "No notifications sent yet"

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let notifyBackgroundCompletionKey = "ImagePet.notifications.backgroundCompletion"
    private let notifyAttentionNeededKey = "ImagePet.notifications.attentionNeeded"
    private let notifyForegroundCompletionKey = "ImagePet.notifications.foregroundCompletion"
    private let categoryIdentifier = "IMAGEPET_COMPRESSION_SUMMARY"
    private var lastAttentionDeliveryByKey: [String: Date] = [:]
    private var summariesByID: [String: BackgroundCompressionSummary] = [:]
    private var actionHandler: ((LocalNotificationAction, BackgroundCompressionSummary?) -> Void)?

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        self.notifyBackgroundCompletion = defaults.object(forKey: notifyBackgroundCompletionKey) as? Bool ?? true
        self.notifyAttentionNeeded = defaults.object(forKey: notifyAttentionNeededKey) as? Bool ?? true
        self.notifyForegroundCompletion = defaults.object(forKey: notifyForegroundCompletionKey) as? Bool ?? false
        super.init()
        center.delegate = self
        registerCategories()
        loadAuthorizationStatus()
    }

    @MainActor
    func setActionHandler(_ handler: @escaping (LocalNotificationAction, BackgroundCompressionSummary?) -> Void) {
        actionHandler = handler
    }

    @MainActor
    func refreshAuthorizationStatus() {
        loadAuthorizationStatus()
    }

    private func loadAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationState = LocalNotificationAuthorizationState(status: settings.authorizationStatus)
            }
        }
    }

    @MainActor
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
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
    func handleCompletedSummary(_ summary: BackgroundCompressionSummary, appIsActive: Bool) {
        lastSummary = summary

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
        center.add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastDeliveryStatus = "Not delivered: \(error.localizedDescription)"
                } else {
                    self?.lastDeliveryStatus = "Delivered \(summary.statusText.lowercased()) notification"
                }
            }
        }
    }

    private func shouldDeliver(_ summary: BackgroundCompressionSummary, appIsActive: Bool) -> Bool {
        if appIsActive && !notifyForegroundCompletion {
            return false
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

    private func passesAttentionThrottle(_ summary: BackgroundCompressionSummary) -> Bool {
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

    private func notificationText(for summary: BackgroundCompressionSummary) -> (title: String, body: String) {
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

    private func outputDescription(for summary: BackgroundCompressionSummary) -> String {
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
        center.setNotificationCategories([category])
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
