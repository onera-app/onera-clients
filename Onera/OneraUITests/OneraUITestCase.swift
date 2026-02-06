//
//  OneraUITestCase.swift
//  OneraUITests
//
//  Base test case for Onera UI tests
//

import XCTest

/// Base class for all Onera UI tests with common setup and helpers
class OneraUITestCase: XCTestCase {
    
    var app: XCUIApplication!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Base launch arguments for all tests
        app.launchArguments = [
            "--uitesting",
            "--disable-animations"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch Helpers
    
    /// Launch the app as unauthenticated user
    func launchUnauthenticated() {
        app.launchArguments.append("--unauthenticated")
        app.launchArguments.append("--reset-state")
        app.launch()
    }
    
    /// Launch the app as authenticated user (fully set up)
    func launchAuthenticated() {
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--skip-biometrics")
        app.launch()
    }
    
    /// Launch the app as authenticated user needing E2EE setup
    func launchNeedsE2EESetup() {
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--needs-e2ee-setup")
        app.launch()
    }
    
    /// Launch the app as authenticated user needing E2EE unlock
    func launchNeedsE2EEUnlock() {
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--needs-e2ee-unlock")
        app.launch()
    }
    
    /// Launch with mock data
    func launchWithMockData() {
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--skip-biometrics")
        app.launchArguments.append("--mock-chats")
        app.launchArguments.append("--mock-notes")
        app.launch()
    }
    
    // MARK: - Wait Helpers
    
    /// Wait for an element to exist
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
    
    /// Wait for an element to disappear
    @discardableResult
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Wait for the app to be ready (launch screen gone)
    func waitForAppReady(timeout: TimeInterval = 15) {
        // Wait for launch view to disappear
        let launchView = app.otherElements["launchView"]
        if launchView.exists {
            waitForElementToDisappear(launchView, timeout: timeout)
        }
    }
    
    // MARK: - Assertion Helpers
    
    /// Assert an element exists and is visible
    func assertExists(_ element: XCUIElement, message: String? = nil) {
        XCTAssertTrue(
            waitForElement(element),
            message ?? "Expected element to exist: \(element.identifier)"
        )
    }
    
    /// Assert an element does not exist
    func assertNotExists(_ element: XCUIElement, message: String? = nil) {
        XCTAssertFalse(
            element.exists,
            message ?? "Expected element to not exist: \(element.identifier)"
        )
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigate to settings (iOS)
    func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        if waitForElement(settingsButton, timeout: 5) {
            settingsButton.tap()
        }
    }
    
    /// Dismiss any presented sheet
    func dismissSheet() {
        let closeButton = app.buttons["Close"]
        if closeButton.exists {
            closeButton.tap()
        } else {
            // Swipe down to dismiss
            app.swipeDown()
        }
    }
    
    // MARK: - Device Helpers
    
    /// Check if running on iPad
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// Check if running on Mac
    var isMac: Bool {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return true
        #else
        return false
        #endif
    }
}
