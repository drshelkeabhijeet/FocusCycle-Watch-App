//
//  FocusCycle_Watch_AppUITests.swift
//  FocusCycle Watch AppUITests
//
//  Created by Abhijeet Shelke on 20/06/25.
//

import XCTest

final class FocusCycle_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLandingShowsPrimaryQuickStartActions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["yoga-quick-start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pranayama-quick-start"].exists)
        XCTAssertTrue(app.buttons["meditation-quick-start"].exists)
    }

    @MainActor
    func testYogaTimerControlsAppearAfterQuickStart() throws {
        let app = XCUIApplication()
        app.launch()

        let yogaStart = app.buttons["yoga-quick-start"]
        XCTAssertTrue(yogaStart.waitForExistence(timeout: 5))
        yogaStart.tap()

        XCTAssertTrue(app.buttons["yoga-start-pause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["yoga-stop-reset"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
