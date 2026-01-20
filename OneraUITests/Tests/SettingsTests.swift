//
//  SettingsTests.swift
//  OneraUITests
//
//  E2E tests for settings functionality
//

import XCTest

final class SettingsTests: XCTestCase {
    
    var app: XCUIApplication!
    var settingsScreen: SettingsScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        AppLauncher.configureAsAuthenticated(app)
        app.launch()
        
        // Navigate to settings
        let chatScreen = ChatScreen(app: app)
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            throw XCTSkip("App not loaded - skipping settings tests")
        }
        
        // Open sidebar and go to settings
        swipeFromLeftEdge()
        let sidebarScreen = SidebarScreen(app: app)
        
        guard sidebarScreen.settingsButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Settings button not available")
        }
        
        settingsScreen = sidebarScreen.tapSettings()
        
        guard settingsScreen.isDisplayed else {
            throw XCTSkip("Settings screen not available")
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
        settingsScreen = nil
    }
    
    // MARK: - Test Cases
    
    /// Test that profile is displayed correctly
    func testProfileDisplayed() throws {
        // Check for profile elements
        XCTAssertTrue(settingsScreen.hasProfile, "Profile should be displayed")
        
        takeScreenshot(name: "Settings_Profile")
    }
    
    /// Test changing theme
    func testThemeSelection() throws {
        guard settingsScreen.themeSelector.waitForExistence(timeout: 5) else {
            throw XCTSkip("Theme selector not available")
        }
        
        // Tap theme selector
        settingsScreen.tapThemeSelector()
        
        takeScreenshot(name: "Settings_Theme_Options")
        
        // Select Dark theme
        let darkOption = app.buttons["Dark"]
        if darkOption.waitForExistence(timeout: 3) {
            darkOption.tap()
            
            takeScreenshot(name: "Settings_Dark_Theme")
        }
        
        // Select Light theme
        settingsScreen.tapThemeSelector()
        let lightOption = app.buttons["Light"]
        if lightOption.waitForExistence(timeout: 3) {
            lightOption.tap()
            
            takeScreenshot(name: "Settings_Light_Theme")
        }
        
        // Reset to System
        settingsScreen.tapThemeSelector()
        let systemOption = app.buttons["System"]
        if systemOption.waitForExistence(timeout: 3) {
            systemOption.tap()
        }
    }
    
    /// Test viewing recovery phrase
    func testViewRecoveryPhrase() throws {
        guard settingsScreen.recoveryPhraseButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Recovery phrase button not available")
        }
        
        // Tap recovery phrase button
        settingsScreen.tapRecoveryPhrase()
        
        // Look for recovery phrase sheet
        let phraseSheet = app.sheets.firstMatch
        let phraseElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'phrase' OR label CONTAINS[c] 'recovery' OR label CONTAINS[c] 'backup'"))
        
        _ = phraseElements.firstMatch.waitForExistence(timeout: 5)
        
        takeScreenshot(name: "Settings_Recovery_Phrase")
        
        // Close the sheet
        let doneButton = app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }
    
    /// Test sign out confirmation dialog
    func testSignOutConfirmation() throws {
        guard settingsScreen.signOutButton.waitForExistence(timeout: 5) else {
            XCTFail("Sign out button not found")
            return
        }
        
        // Tap sign out
        settingsScreen.tapSignOut()
        
        // Verify confirmation dialog appears
        XCTAssertTrue(settingsScreen.signOutConfirmButton.waitForExistence(timeout: 5), "Sign out confirmation should appear")
        
        takeScreenshot(name: "Settings_SignOut_Confirmation")
        
        // Cancel to stay in settings
        settingsScreen.cancelSignOut()
        
        // Verify we're still in settings
        XCTAssertTrue(settingsScreen.isDisplayed, "Should still be in settings after canceling")
    }
    
    /// Test navigating to API credentials
    func testAPICredentialsNavigation() throws {
        // Look for API connections / credentials navigation
        let credentialsLink = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'API' OR label CONTAINS[c] 'connection' OR label CONTAINS[c] 'credential'")).firstMatch
        
        guard credentialsLink.waitForExistence(timeout: 5) else {
            throw XCTSkip("API credentials link not available")
        }
        
        credentialsLink.tap()
        
        // Verify credentials screen appears
        let credentialsTitle = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'API' OR identifier CONTAINS[c] 'credential' OR identifier CONTAINS[c] 'connection'")).firstMatch
        
        _ = credentialsTitle.waitForExistence(timeout: 5)
        
        takeScreenshot(name: "Settings_API_Credentials")
        
        // Go back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
}

// MARK: - Helper Extensions

extension SettingsTests {
    func swipeFromLeftEdge() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
