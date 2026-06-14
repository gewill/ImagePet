import XCTest

final class ImagePetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        if name.contains("Restoration") {
            app.launchEnvironment["IS_UI_TESTING_RESTORATION"] = "1"
        } else {
            app.launchArguments += ["-ImagePetResetWindowFrame", "YES"]
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    private func mainWindow(timeout: TimeInterval = 3.0) -> XCUIElement {
        let titledWindow = app.windows["ImagePet"]
        if titledWindow.waitForExistence(timeout: 0.5) {
            return titledWindow
        }

        let contentWindow = app.windows.containing(.button, identifier: "togglePetButton").firstMatch
        _ = contentWindow.waitForExistence(timeout: timeout)
        return contentWindow
    }

    private func desktopPetEmoji(in petWindow: XCUIElement) -> XCUIElement {
        let button = petWindow.buttons["desktopPetEmoji"]
        if button.exists {
            return button
        }

        let staticText = petWindow.staticTexts["desktopPetEmoji"]
        if staticText.exists {
            return staticText
        }

        return petWindow.descendants(matching: .any)["desktopPetEmoji"]
    }

    private func waitForExpandedPetWindow(_ petWindow: XCUIElement, timeout: TimeInterval = 2.0) {
        let expanded = NSPredicate { element, _ in
            guard let petWindow = element as? XCUIElement else { return false }
            return petWindow.frame.width >= 180
        }
        let expectation = XCTNSPredicateExpectation(predicate: expanded, object: petWindow)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitForMiniPetWindow(_ petWindow: XCUIElement, timeout: TimeInterval = 2.0) {
        let collapsed = NSPredicate { element, _ in
            guard let petWindow = element as? XCUIElement else { return false }
            return petWindow.frame.width <= 100
        }
        let expectation = XCTNSPredicateExpectation(predicate: collapsed, object: petWindow)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    func testLaunchAndInitialLayout() throws {
        // Assert main window is open
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Assert empty jobs label exists initially
        let emptyLabel = window.staticTexts["emptyJobsLabel"]
        XCTAssertTrue(emptyLabel.exists)
        XCTAssertTrue(emptyLabel.textContent.contains("No images in queue"))

        // Assert that the default output directory has been automatically chosen
        let outputLabel = window.staticTexts["outputFolderLabel"]
        XCTAssertTrue(outputLabel.exists)
        XCTAssertTrue(outputLabel.textContent.contains("Output Folder:"))
    }

    func testPresetPicker() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Find segmented picker
        let picker = window.radioGroups["presetPicker"]
        XCTAssertTrue(picker.exists)

        // Select 'High' preset
        let highButton = picker.radioButtons["High"]
        XCTAssertTrue(highButton.exists)
        highButton.click()

        // Select 'Small' preset
        let smallButton = picker.radioButtons["Small"]
        XCTAssertTrue(smallButton.exists)
        smallButton.click()
    }

    func testMiniFullResizeCentering() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Choose output folder first to resolve needsSetup blocking state!
        let chooseFolderButton = window.buttons["chooseFolderButton"]
        XCTAssertTrue(chooseFolderButton.exists)
        chooseFolderButton.click()

        // Show Desktop Pet
        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        // Get initial mini center
        waitForMiniPetWindow(petWindow)
        let miniFrame = petWindow.frame
        let miniCenterX = miniFrame.midX
        let miniCenterY = miniFrame.midY

        // Expand
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        waitForExpandedPetWindow(petWindow)
        let fullFrame = petWindow.frame
        let fullCenterX = fullFrame.midX
        let fullCenterY = fullFrame.midY

        // Check if centers are within 1 pixel
        XCTAssertEqual(miniCenterX, fullCenterX, accuracy: 1.0)
        XCTAssertEqual(miniCenterY, fullCenterY, accuracy: 1.0)

        // Collapse back to mini
        let collapseButton = petWindow.buttons["collapsePetButton"]
        XCTAssertTrue(collapseButton.exists)
        collapseButton.click()

        waitForMiniPetWindow(petWindow)
        let restoredFrame = petWindow.frame
        let restoredCenterX = restoredFrame.midX
        let restoredCenterY = restoredFrame.midY

        XCTAssertEqual(miniCenterX, restoredCenterX, accuracy: 1.0)
        XCTAssertEqual(miniCenterY, restoredCenterY, accuracy: 1.0)

        // Close the pet
        toggleButton.click()
    }

    func testToggleDesktopPet() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Choose output folder first to resolve needsSetup blocking state!
        let chooseFolderButton = window.buttons["chooseFolderButton"]
        XCTAssertTrue(chooseFolderButton.exists)
        chooseFolderButton.click()

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)

        // Initially Desktop Pet window shouldn't exist because we bypassed state restoration
        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertFalse(petWindow.exists)

        // Click to show Desktop Pet
        toggleButton.click()

        // Wait since UI updates on window displays might be asynchronous
        let petWindowExists = petWindow.waitForExistence(timeout: 2.0)
        XCTAssertTrue(petWindowExists)

        // Verify elements inside DesktopPetWindow (starts in Mini mode)
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        waitForMiniPetWindow(petWindow)

        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertFalse(petTitle.exists)

        // Click to expand
        petEmoji.click()
        XCTAssertTrue(petTitle.waitForExistence(timeout: 2.0))
        XCTAssertEqual(petTitle.textContent, "Ready")
        waitForExpandedPetWindow(petWindow)

        // Close the pet using the window close button
        let closeButton = petWindow.buttons["closePetButton"]
        XCTAssertTrue(closeButton.exists)
        closeButton.click()

        // Verify it is closed by waiting for disappearance.
        let disappeared = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: disappeared, object: petWindow)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(result, .completed, "Desktop pet window should close")
    }

    func testDesktopPetReturnButtonReopensMainWindow() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        // Expand
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        let closeButton = window.buttons["Close"]
        if closeButton.exists {
            closeButton.click()
        } else {
            window.click()
            app.typeKey("w", modifierFlags: [.command])
        }

        let mainWindowDisappeared = NSPredicate(format: "exists == false")
        let mainWindowClosed = XCTNSPredicateExpectation(predicate: mainWindowDisappeared, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [mainWindowClosed], timeout: 2.0), .completed)

        let returnButton = petWindow.buttons["desktopPetReturnToAppButton"]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 2.0))
        returnButton.click()

        XCTAssertTrue(mainWindow().waitForExistence(timeout: 3.0))
    }

    func testCompressionFlow() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Add images using our mocked InputFilePanel
        let addImagesButton = window.buttons["addImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        // Verify job rows appear in the UI by querying specific text elements
        let filename1 = window.staticTexts.matching(identifier: "jobFileName_sample1.png").firstMatch
        let filename2 = window.staticTexts.matching(identifier: "jobFileName_sample2.png").firstMatch

        XCTAssertTrue(filename1.waitForExistence(timeout: 5.0))
        XCTAssertTrue(filename2.waitForExistence(timeout: 5.0))

        // Wait until compression is completed (Done status shows up)
        let status1 = window.staticTexts.matching(identifier: "jobStatusText_sample1.png").firstMatch
        let status2 = window.staticTexts.matching(identifier: "jobStatusText_sample2.png").firstMatch

        XCTAssertTrue(status1.waitForExistence(timeout: 5.0))
        XCTAssertTrue(status2.waitForExistence(timeout: 5.0))

        XCTAssertEqual(status1.textContent, "Done")
        XCTAssertEqual(status2.textContent, "Done")

        // Let's verify summary metrics show up after done
        let ateMetric = window.staticTexts["summaryMetricTitle_Ate"]
        let poopedMetric = window.staticTexts["summaryMetricTitle_Pooped"]
        let savedMetric = window.staticTexts["summaryMetricTitle_Saved"]

        XCTAssertTrue(ateMetric.waitForExistence(timeout: 2.0))
        XCTAssertTrue(poopedMetric.exists)
        XCTAssertTrue(savedMetric.exists)

        // Verify 'Reveal in Finder' and 'Compress More' buttons exist
        let revealButton = window.buttons["revealInFinderButton"]
        let compressMoreButton = window.buttons["compressMoreButton"]
        XCTAssertTrue(revealButton.exists)
        XCTAssertTrue(compressMoreButton.exists)

        // Click 'Compress More' to reset the state
        compressMoreButton.click()

        // Empty state label should be visible again
        let emptyLabel = window.staticTexts["emptyJobsLabel"]
        XCTAssertTrue(emptyLabel.exists)
    }

    func testDesktopPetDoneActions() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Show Desktop Pet
        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        // Expand
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        // Trigger Add Images from Pet
        let addImagesButton = petWindow.buttons["desktopPetAddImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        // Wait until pet title is "Done"
        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)

        let doneExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Done' OR value == 'Done'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [doneExpectation], timeout: 5.0), .completed)

        // Verify Reveal and Compress More buttons exist
        let revealButton = petWindow.buttons["desktopPetRevealButton"]
        let compressMoreButton = petWindow.buttons["desktopPetCompressMoreButton"]
        XCTAssertTrue(revealButton.exists)
        XCTAssertTrue(compressMoreButton.exists)

        // Click Compress More to reset state
        compressMoreButton.click()

        // Verify title resets to Ready
        let readyExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ready' OR value == 'Ready'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [readyExpectation], timeout: 2.0), .completed)
    }

    func testDesktopPetRetryAction() throws {
        // Relaunch app with UI_TEST_FAIL environment variable
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_FAIL"] = "1"
        app.launchEnvironment["UI_TEST_SLOW_PROCESS"] = "1"
        app.launch()

        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        // Expand
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        let addImagesButton = petWindow.buttons["desktopPetAddImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        // Wait until pet title is "Issues"
        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)
        let issuesExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Issues' OR value == 'Issues'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [issuesExpectation], timeout: 5.0), .completed)

        let failedStatus = window.staticTexts.matching(identifier: "jobStatusText_badfile.png").firstMatch
        XCTAssertTrue(failedStatus.waitForExistence(timeout: 2.0))
        XCTAssertTrue(failedStatus.textContent.hasPrefix("Failed"))

        // Verify Retry Failed button exists
        let retryButton = petWindow.buttons["desktopPetRetryFailedButton"]
        XCTAssertTrue(retryButton.exists)

        retryButton.click()

        let eatingExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Eating' OR value == 'Eating'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [eatingExpectation], timeout: 2.0), .completed)

        let issuesExpectation2 = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Issues' OR value == 'Issues'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [issuesExpectation2], timeout: 5.0), .completed)
        XCTAssertTrue(failedStatus.textContent.hasPrefix("Failed"))
    }

    func testDesktopPetOverwritesDialog() throws {
        // Relaunch app with UI_TEST_OVERWRITE environment variable
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_OVERWRITE"] = "1"
        app.launch()

        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        // Expand
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        // Close the main window so the Pet must route destructive confirmation back through the app.
        let closeButton = window.buttons["Close"]
        if closeButton.exists {
            closeButton.click()
        } else {
            window.click()
            app.typeKey("w", modifierFlags: [.command])
        }

        let addImagesButton = petWindow.buttons["desktopPetAddImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        XCTAssertTrue(mainWindow(timeout: 3.0).exists)

        // Verify alert sheet/dialog is displayed
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3.0))

        // Click Cancel on the sheet
        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.click()

        // Canceling a destructive overwrite is a normal failed batch, not a permission problem.
        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)
        let issuesExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Issues' OR value == 'Issues'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [issuesExpectation], timeout: 3.0), .completed)
        XCTAssertTrue(petWindow.buttons["desktopPetCompressMoreButton"].exists)
    }

    func testDesktopPetBlockingConfirmForcesFullFromMini() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_OVERWRITE"] = "1"
        app.launch()

        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        XCTAssertFalse(petWindow.staticTexts["desktopPetTitle"].exists)
        waitForMiniPetWindow(petWindow)

        let addImagesButton = window.buttons["addImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        let confirmExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Confirm overwrite' OR value == 'Confirm overwrite'"),
            object: petTitle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [confirmExpectation], timeout: 3.0), .completed)
        waitForExpandedPetWindow(petWindow)

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3.0))
        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.click()
    }

    func testDesktopPetFullCollapsesToMini() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)

        // Expand
        petEmoji.click()

        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.waitForExistence(timeout: 2.0))
        waitForExpandedPetWindow(petWindow)

        // Find collapse button
        let collapseButton = petWindow.buttons["collapsePetButton"]
        XCTAssertTrue(collapseButton.exists)
        collapseButton.click()

        // Verify title disappears (collapsed back to mini)
        let disappeared = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: disappeared, object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2.0), .completed)
        waitForMiniPetWindow(petWindow)
    }

    func testDoneStateAutoExitsAfterThreeSeconds() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        let addImagesButton = petWindow.buttons["desktopPetAddImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)
        let doneExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Done' OR value == 'Done'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [doneExpectation], timeout: 5.0), .completed)

        let readyExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ready' OR value == 'Ready'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [readyExpectation], timeout: 4.0), .completed)
    }

    func testIssuesStateDegradesAfterTimeout() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["UI_TEST_FAIL"] = "1"
        app.launch()

        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)
        toggleButton.click()

        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))

        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        let addImagesButton = petWindow.buttons["desktopPetAddImagesButton"]
        XCTAssertTrue(addImagesButton.exists)
        addImagesButton.click()

        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)
        let issuesExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Issues' OR value == 'Issues'"), object: petTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [issuesExpectation], timeout: 5.0), .completed)

        Thread.sleep(forTimeInterval: 3.0)

        XCTAssertEqual(petTitle.textContent, "Issues")

        let retryButton = petWindow.buttons["desktopPetRetryFailedButton"]
        XCTAssertTrue(retryButton.exists)
    }

    func testDesktopPetStateRestoration() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["IS_UI_TESTING_RESTORATION"] = "1"
        app.launch()

        let window = mainWindow()
        XCTAssertTrue(window.exists)

        let chooseFolderButton = window.buttons["chooseFolderButton"]
        XCTAssertTrue(chooseFolderButton.exists)
        chooseFolderButton.click()

        let toggleButton = window.buttons["togglePetButton"]
        XCTAssertTrue(toggleButton.exists)

        let petWindow = app.windows["DesktopPetWindow"]
        if !petWindow.exists {
            toggleButton.click()
            XCTAssertTrue(petWindow.waitForExistence(timeout: 2.0))
        }

        app.terminate()

        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["IS_UI_TESTING_RESTORATION"] = "1"
        app.launch()

        let petWindow2 = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow2.waitForExistence(timeout: 8.0), "Desktop pet window should be restored on launch")

        let window2 = mainWindow()
        if window2.exists {
            let toggleButton2 = window2.buttons["togglePetButton"]
            if toggleButton2.exists && petWindow2.exists {
                toggleButton2.click()
            }
        }
    }

    func testPRDv07NewSettings() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Switch to the Settings Tab
        let tab = window.descendants(matching: .any)["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 2.0))
        tab.click()

        // Test petSettingsEnabledToggle
        let enabledToggle = window.descendants(matching: .any)["petSettingsEnabledToggle"]
        XCTAssertTrue(enabledToggle.exists)

        let catCard = window.buttons["themeCard_CuteCat"]
        XCTAssertTrue(catCard.exists)
        XCTAssertTrue(catCard.isEnabled)

        // Toggle it off, cards should be disabled
        enabledToggle.click()
        XCTAssertFalse(catCard.isEnabled)

        // Toggle it back on
        enabledToggle.click()
        XCTAssertTrue(catCard.isEnabled)

        let shibaCard = window.buttons["themeCard_ShibaInu"]
        XCTAssertTrue(shibaCard.exists)
        shibaCard.click()

        let slimeCard = window.buttons["themeCard_PixelSlime"]
        XCTAssertTrue(slimeCard.exists)
        slimeCard.click()

        let launchToggle = window.descendants(matching: .any)["launchAtLoginToggle"]
        XCTAssertTrue(launchToggle.exists)
        launchToggle.click()

        let energyToggle = window.descendants(matching: .any)["energySavingModeToggle"]
        XCTAssertTrue(energyToggle.exists)
        energyToggle.click()
    }

    func testQuietStartupWithPetEnabledAndVisible() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["IMAGEPET_LAUNCH_MODE"] = "loginItem"
        app.launchEnvironment["IMAGEPET_MOCK_PET_ENABLED"] = "1"
        app.launchEnvironment["IMAGEPET_MOCK_PET_VISIBLE"] = "1"
        app.launch()

        // Verify main window does not exist
        let window = app.windows["ImagePet"]
        XCTAssertFalse(window.exists)

        // Verify desktop pet window exists and is collapsed
        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertTrue(petWindow.waitForExistence(timeout: 8.0))
        waitForMiniPetWindow(petWindow)

        // Click pet to expand it
        let petEmoji = desktopPetEmoji(in: petWindow)
        XCTAssertTrue(petEmoji.exists)
        petEmoji.click()

        // Verify return button exists and click it
        let returnBtn = petWindow.buttons["desktopPetReturnToAppButton"]
        XCTAssertTrue(returnBtn.waitForExistence(timeout: 2.0))
        returnBtn.click()

        // Verify main window is now visible
        XCTAssertTrue(window.waitForExistence(timeout: 3.0))
    }

    func testQuietStartupWithPetDisabled() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
        app.launchEnvironment["IMAGEPET_LAUNCH_MODE"] = "loginItem"
        app.launchEnvironment["IMAGEPET_MOCK_PET_ENABLED"] = "0"
        app.launch()

        // Verify main window does not exist
        let window = app.windows["ImagePet"]
        XCTAssertFalse(window.exists)

        // Verify desktop pet window does not exist either
        let petWindow = app.windows["DesktopPetWindow"]
        XCTAssertFalse(petWindow.exists)
    }
}

private extension XCUIElement {
    var textContent: String {
        if let valStr = value as? String, !valStr.isEmpty {
            return valStr
        }
        return label
    }
}
