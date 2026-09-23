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
        XCTAssertTrue(app.descendants(matching: .any)["Happy logged."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()

        // The action now offers an update and the status line reflects the fresh mood
        // (the accessory on iOS 26 and the prominent tab on iOS 27 both carry the same label).
        XCTAssertTrue(app.buttons["Update your mood"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'happy for you'")).firstMatch.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "home-after-log"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIntensityRefinementUpdatesEntry() {
        let logButton = app.buttons["Log your mood"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 8))
        logButton.tap()
        app.buttons["Stressed"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        // Segmented control on iOS 26, tabs picker on iOS 27: both expose the segment as a button.
        let very = app.buttons["Very"]
        XCTAssertTrue(very.waitForExistence(timeout: 5))
        very.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'slow breaths'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testHistoryShowsTodayAndSupportIsReachable() {
        app.buttons["Log your mood"].tap()
        app.buttons["Calm"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pebble had a gentle day."].exists)

        app.tabBars.buttons["You"].tap()
        let support = app.buttons["Support and crisis resources"]
        for _ in 0..<6 where !support.exists { app.swipeUp() }
        XCTAssertTrue(support.waitForExistence(timeout: 5))
        support.tap()
        XCTAssertTrue(app.staticTexts["Call or text 988"].waitForExistence(timeout: 5))
    }

    func testPetScreenIsAccessible() {
        let pet = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Pebble looks' OR label BEGINSWITH 'Pebble is'")).firstMatch
        XCTAssertTrue(pet.waitForExistence(timeout: 5), "The pet must expose a VoiceOver label describing its mood")
    }
    func testBreathingCanStartAndStop() {
        // Wait for the room like every other test does: a cold runner can still be launching.
        let sit = app.buttons["Sit with Pebble"]
        XCTAssertTrue(sit.waitForExistence(timeout: 8))
        sit.tap()
        let breathe = app.buttons["Breathe together"]
        XCTAssertTrue(breathe.waitForExistence(timeout: 5))
        breathe.tap()
        let stop = app.buttons["Stop breathing guide"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(breathe.exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Log your mood"].waitForExistence(timeout: 8) || app.tabBars.buttons["Pet"].waitForExistence(timeout: 2))
    }

}
