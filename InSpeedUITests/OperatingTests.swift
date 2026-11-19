import XCTest

final class OperatingTests: XCTestCase {
    func testTripSurvivesLayoutAndNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let control = app.buttons["tripControl"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        control.tap()
        XCTAssertEqual(control.label, "STOP")
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(control.isHittable)
            XCTAssertEqual(control.label, "STOP")
            let liveTab = app.buttons["Live"]
            if orientation == .portrait {
                XCTAssertGreaterThan(control.frame.minY, liveTab.frame.maxY)
            } else {
                XCTAssertGreaterThan(control.frame.minX, liveTab.frame.maxX)
            }
            app.buttons["Compass"].tap()
            XCTAssertEqual(control.label, "STOP")
            app.buttons["Speed"].tap()
            app.buttons["Trips"].tap()
            app.buttons["Totals"].tap()
            let totalTrips = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Total trips")).firstMatch
            XCTAssertTrue(totalTrips.waitForExistence(timeout: 5))
            app.buttons["Live"].tap()
            XCTAssertEqual(control.label, "STOP")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Live – " + orientation.rawValue.description
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.buttons["Full Screen"].tap()
        XCTAssertFalse(app.buttons["Trips"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(control.label, "STOP")
        control.tap()
        XCTAssertEqual(control.label, "START")
        app.buttons["Trips"].tap()
        app.buttons["History"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Driving")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(app.navigationBars["Trip details"].exists)
    }
}
