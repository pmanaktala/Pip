import XCTest

/// The one flow that matters: open → tap a mood → done.
final class MoodLoggingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["PIP_UITEST"] = "1"
        app.launch()
    }

    func testLogMoodInTwoTaps() {
        let logButton = app.buttons["Log your mood"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()

        let happy = app.buttons["Happy"]
        XCTAssertTrue(happy.waitForExistence(timeout: 5))
        happy.tap()

        // The sheet morphs into the optional refinement step; nothing else is required.
        XCTAssertTrue(app.navigationBars.staticTexts["Pebble looks happy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()

        // Main screen now reflects the fresh mood.
        XCTAssertTrue(app.buttons["Update your mood"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Happy"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "home-after-log"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIntensityRefinementUpdatesEntry() {
        app.buttons["Log your mood"].tap()
        app.buttons["Stressed"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Very"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Very stressed"].waitForExistence(timeout: 5))
    }

    func testPetScreenIsAccessible() {
        let pet = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Pebble looks' OR label BEGINSWITH 'Pebble is'")).firstMatch
        XCTAssertTrue(pet.waitForExistence(timeout: 5), "The pet must expose a VoiceOver label describing its mood")
    }
    func testBreathingCanStartAndStop() {
        app.buttons["Sit with Pebble"].tap()
        let breathe = app.buttons["Breathe together"]
        XCTAssertTrue(breathe.waitForExistence(timeout: 5))
        breathe.tap()
        let stop = app.buttons["Stop guided breathing"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(breathe.exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Log your mood"].waitForExistence(timeout: 5))
    }

}
