//
//  XCTestCase+Extensions.swift
//  OneraUITests
//
//  Common test utilities and extensions
//

import XCTest

extension XCTestCase {
    
    /// Wait for an element to exist with a custom timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Wait for an element to not exist
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Tap an element if it exists
    func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 5) {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
        }
    }
    
    /// Type text into a text field, clearing it first
    func clearAndType(_ element: XCUIElement, text: String) {
        element.tap()
        
        // Select all and delete
        if let currentValue = element.value as? String, !currentValue.isEmpty {
            element.tap()
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteString)
        }
        
        element.typeText(text)
    }
    
    /// Take a screenshot with a name
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    /// Swipe from left edge to open drawer
    func swipeFromLeftEdge(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
    
    /// Swipe to close drawer
    func swipeToCloseDrawer(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}

// MARK: - App Launch Helpers

extension XCUIApplication {
    
    /// Launch the app with UI testing configuration
    func launchForTesting() {
        launchArguments = ["--uitesting"]
        launch()
    }
    
    /// Launch with a specific authenticated state
    func launchAuthenticated() {
        launchArguments = ["--uitesting", "--authenticated"]
        launch()
    }
    
    /// Launch in unauthenticated state
    func launchUnauthenticated() {
        launchArguments = ["--uitesting", "--unauthenticated"]
        launch()
    }
}
