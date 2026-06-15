import XCTest
import UserNotifications
@testable import ImagePetCore

final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var delegate: UNUserNotificationCenterDelegate?
    var mockStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationCalled = false
    var addedRequests: [UNNotificationRequest] = []

    func getSettings(completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        completionHandler(mockStatus)
    }

    func requestAuth(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
        requestAuthorizationCalled = true
        mockStatus = .authorized
        completionHandler(true, nil)
    }

    func addRequest(_ request: UNNotificationRequest, completionHandler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        // No-op
    }
}

final class LocalNotificationManagerTests: XCTestCase {
    private var mockCenter: MockNotificationCenter!
    private var defaults: UserDefaults!
    private var manager: LocalNotificationManager!

    @MainActor
    override func setUp() {
        super.setUp()
        mockCenter = MockNotificationCenter()
        defaults = UserDefaults(suiteName: "org.gewill.ImagePet.test.defaults")!
        defaults.removePersistentDomain(forName: "org.gewill.ImagePet.test.defaults")
        
        manager = LocalNotificationManager(center: mockCenter, defaults: defaults)
    }

    @MainActor
    override func tearDown() {
        defaults.removePersistentDomain(forName: "org.gewill.ImagePet.test.defaults")
        defaults = nil
        manager = nil
        mockCenter = nil
        super.tearDown()
    }

    // 1. Test CompressionBatchSummary merging
    func testSummaryMerging() {
        let first = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 2,
            failedCount: 1,
            skippedCount: 0,
            totalInputBytes: 100,
            totalOutputBytes: 60,
            outputDirectory: URL(fileURLWithPath: "/tmp/a"),
            representativeOutputURL: URL(fileURLWithPath: "/tmp/a/img1.jpg"),
            requiresUserAction: true,
            primaryErrorMessage: "Fail 1",
            completedAt: Date(timeIntervalSince1970: 1000)
        )

        let second = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 3,
            failedCount: 0,
            skippedCount: 1,
            totalInputBytes: 200,
            totalOutputBytes: 120,
            outputDirectory: URL(fileURLWithPath: "/tmp/a"),
            representativeOutputURL: URL(fileURLWithPath: "/tmp/a/img2.jpg"),
            requiresUserAction: false,
            primaryErrorMessage: nil,
            completedAt: Date(timeIntervalSince1970: 2000)
        )

        let merged = first.merging(second)

        XCTAssertEqual(merged.source, .folderWatching)
        XCTAssertEqual(merged.successfulCount, 5)
        XCTAssertEqual(merged.failedCount, 1)
        XCTAssertEqual(merged.skippedCount, 1)
        XCTAssertEqual(merged.totalInputBytes, 300)
        XCTAssertEqual(merged.totalOutputBytes, 180)
        XCTAssertEqual(merged.outputDirectory, URL(fileURLWithPath: "/tmp/a"))
        XCTAssertEqual(merged.representativeOutputURL, URL(fileURLWithPath: "/tmp/a/img1.jpg"))
        XCTAssertTrue(merged.requiresUserAction)
        XCTAssertEqual(merged.primaryErrorMessage, "Fail 1")
        XCTAssertEqual(merged.completedAt, Date(timeIntervalSince1970: 2000))
    }

    // 2. Test History Persistence (max 20)
    @MainActor
    func testHistoryPersistenceAndCap() {
        XCTAssertTrue(manager.recentSummaries.isEmpty)

        // Add 25 summaries
        for i in 1...25 {
            let summary = CompressionBatchSummary(
                id: UUID(),
                source: .manual,
                successfulCount: i,
                failedCount: 0,
                skippedCount: 0,
                totalInputBytes: 100,
                totalOutputBytes: 50,
                outputDirectory: nil,
                representativeOutputURL: nil,
                requiresUserAction: false,
                primaryErrorMessage: nil
            )
            manager.handleCompletedSummary(summary, appIsActive: false)
        }

        // Verify history is capped at 20 and ordered descending (newest first)
        XCTAssertEqual(manager.recentSummaries.count, 20)
        XCTAssertEqual(manager.recentSummaries.first?.successfulCount, 25)
        XCTAssertEqual(manager.recentSummaries.last?.successfulCount, 6)

        // Verify loaded from defaults
        let newManager = LocalNotificationManager(center: mockCenter, defaults: defaults)
        XCTAssertEqual(newManager.recentSummaries.count, 20)
        XCTAssertEqual(newManager.recentSummaries.first?.successfulCount, 25)
    }

    private func waitForAuthorization(_ expected: LocalNotificationAuthorizationState = .authorized) async {
        let start = Date()
        while manager.authorizationState != expected {
            if Date().timeIntervalSince(start) > 2.0 {
                XCTFail("Timed out waiting for authorization state \(expected)")
                break
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // 3. Test Shortcuts Policy (Success is silent, failures notify)
    @MainActor
    func testShortcutsNotificationPolicy() async {
        mockCenter.mockStatus = .authorized
        manager.refreshAuthorizationStatus()
        await waitForAuthorization(.authorized)

        // Success summary
        let successSummary = CompressionBatchSummary(
            source: .shortcuts,
            successfulCount: 3,
            failedCount: 0,
            skippedCount: 0,
            totalInputBytes: 100,
            totalOutputBytes: 50,
            outputDirectory: nil,
            representativeOutputURL: nil,
            requiresUserAction: false,
            primaryErrorMessage: nil
        )

        // Failure summary
        let failureSummary = CompressionBatchSummary(
            source: .shortcuts,
            successfulCount: 0,
            failedCount: 1,
            skippedCount: 0,
            totalInputBytes: 100,
            totalOutputBytes: 50,
            outputDirectory: nil,
            representativeOutputURL: nil,
            requiresUserAction: true,
            primaryErrorMessage: "Format error"
        )

        // Success should not deliver (remain silent)
        manager.deliverSummaryImmediately(successSummary, appIsActive: false)
        XCTAssertEqual(manager.lastDeliveryStatus, "Not delivered: visible in ImagePet")

        // Failure should attempt to deliver
        manager.deliverSummaryImmediately(failureSummary, appIsActive: false)
        // Verify mockCenter received request
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(mockCenter.addedRequests.first?.content.title, "Shortcuts needs attention")
    }

    // 4. Test Folder Watching Success Policy
    @MainActor
    func testFolderWatchingNotificationPolicy() async {
        mockCenter.mockStatus = .authorized
        manager.refreshAuthorizationStatus()
        await waitForAuthorization(.authorized)

        let successSummary = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 3,
            failedCount: 0,
            skippedCount: 0,
            totalInputBytes: 100,
            totalOutputBytes: 50,
            outputDirectory: nil,
            representativeOutputURL: nil,
            requiresUserAction: false,
            primaryErrorMessage: nil
        )

        // 1. By default, folder watching success is silent
        manager.notifyFolderWatchingCompletion = false
        manager.deliverSummaryImmediately(successSummary, appIsActive: false)
        XCTAssertEqual(manager.lastDeliveryStatus, "Not delivered: visible in ImagePet")
        XCTAssertEqual(mockCenter.addedRequests.count, 0)

        // 2. When enabled, folder watching success attempts to deliver
        manager.notifyFolderWatchingCompletion = true
        manager.deliverSummaryImmediately(successSummary, appIsActive: false)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    // 5. Test 10-Minute Attention Throttle
    @MainActor
    func testAttentionThrottle() async {
        mockCenter.mockStatus = .authorized
        manager.refreshAuthorizationStatus()
        await waitForAuthorization(.authorized)

        let summary1 = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 0,
            failedCount: 1,
            skippedCount: 0,
            totalInputBytes: 0,
            totalOutputBytes: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/watch"),
            representativeOutputURL: nil,
            requiresUserAction: true,
            primaryErrorMessage: "Bookmark resolution error"
        )

        let summary2 = CompressionBatchSummary(
            source: .folderWatching,
            successfulCount: 0,
            failedCount: 1,
            skippedCount: 0,
            totalInputBytes: 0,
            totalOutputBytes: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/watch"),
            representativeOutputURL: nil,
            requiresUserAction: true,
            primaryErrorMessage: "Bookmark resolution error"
        )

        // First delivery should pass shouldDeliver and add to mockCenter
        manager.deliverSummaryImmediately(summary1, appIsActive: false)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)

        // Second delivery within 10 mins with same key should be blocked by throttle (visible in ImagePet)
        manager.deliverSummaryImmediately(summary2, appIsActive: false)
        XCTAssertEqual(manager.lastDeliveryStatus, "Not delivered: visible in ImagePet")
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    // 6. Test 2-Second Coalescing Aggregation
    @MainActor
    func testFolderWatchingCoalescingDebounce() async throws {
        mockCenter.mockStatus = .authorized
        manager.refreshAuthorizationStatus()
        await waitForAuthorization(.authorized)

        let first = CompressionBatchSummary(
            id: UUID(),
            source: .folderWatching,
            successfulCount: 2,
            failedCount: 0,
            skippedCount: 0,
            totalInputBytes: 100,
            totalOutputBytes: 60,
            outputDirectory: URL(fileURLWithPath: "/tmp/watch"),
            representativeOutputURL: nil,
            requiresUserAction: false,
            primaryErrorMessage: nil
        )

        let second = CompressionBatchSummary(
            id: UUID(),
            source: .folderWatching,
            successfulCount: 3,
            failedCount: 0,
            skippedCount: 0,
            totalInputBytes: 200,
            totalOutputBytes: 120,
            outputDirectory: URL(fileURLWithPath: "/tmp/watch"),
            representativeOutputURL: nil,
            requiresUserAction: false,
            primaryErrorMessage: nil
        )

        // Aggregation requires notifyFolderWatchingCompletion to be true for successful deliveries
        manager.notifyFolderWatchingCompletion = true

        manager.handleCompletedSummary(first, appIsActive: false)
        // Verify intermediate merged state is recorded
        XCTAssertEqual(manager.lastSummary?.successfulCount, 2)
        XCTAssertEqual(mockCenter.addedRequests.count, 0)

        // Send second batch 0.5s later
        try await Task.sleep(nanoseconds: 500_000_000)
        manager.handleCompletedSummary(second, appIsActive: false)
        XCTAssertEqual(manager.lastSummary?.successfulCount, 5)
        XCTAssertEqual(mockCenter.addedRequests.count, 0)

        // Wait 2.2s for completion delivery
        try await Task.sleep(nanoseconds: 2_200_000_000)
        
        // Verify delivery was attempted for the merged summary of 5 files
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(mockCenter.addedRequests.first?.content.body, "Saved 0 KB. Output: Watched destination.")
    }
}
