import XCTest

final class ImagePetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["IS_UI_TESTING"] = "1"
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

    func testLaunchAndInitialLayout() throws {
        // Assert main window is open
        let window = mainWindow()
        XCTAssertTrue(window.exists)

        // Assert empty jobs label exists initially
        let emptyLabel = window.staticTexts["emptyJobsLabel"]
        XCTAssertTrue(emptyLabel.exists)
        XCTAssertEqual(emptyLabel.textContent, "No images yet")

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

    func testToggleDesktopPet() throws {
        let window = mainWindow()
        XCTAssertTrue(window.exists)

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

        // Verify elements inside DesktopPetWindow
        let petEmoji = petWindow.staticTexts["desktopPetEmoji"]
        XCTAssertTrue(petEmoji.exists)
        
        let petTitle = petWindow.staticTexts["desktopPetTitle"]
        XCTAssertTrue(petTitle.exists)
        XCTAssertEqual(petTitle.textContent, "Ready")

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
}

private extension XCUIElement {
    var textContent: String {
        if let valStr = value as? String, !valStr.isEmpty {
            return valStr
        }
        return label
    }
}
