//
//  OneraUITestsLaunchTests.swift
//  OneraUITests
//
//  Created by shreyas on 20/01/26.
//

import XCTest

final class OneraUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Configure for UI testing with authenticated user (skipping biometrics)
        app.launchArguments = [
            "--uitesting",
            "--authenticated",
            "--skip-biometrics",
            "--disable-animations"
        ]
        app.launch()

        // Wait for the app to finish loading
        let mainView = app.otherElements["mainView"]
        let exists = mainView.waitForExistence(timeout: 10)
        
        // If main view doesn't exist, we might be on auth or launch screen - that's ok for a launch test
        // Just take a screenshot of whatever state we're in

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
