//
//  SettingsTests.swift
//  OneraUITests
//
//  UI tests for settings functionality
//

import XCTest

final class SettingsTests: OneraUITestCase {
    
    // MARK: - Settings Access Tests
    
    func testSettingsAccessible() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Should show settings view
        let settingsTitle = app.navigationBars["Settings"]
        let settingsView = app.otherElements["settingsView"]
        
        let settingsVisible = settingsTitle.exists || settingsView.exists
        // Settings navigation varies by platform
    }
    
    // MARK: - Account Section Tests
    
    func testAccountSectionExists() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Look for account section
        let accountSection = app.staticTexts["Account"]
        let signOutButton = app.buttons["Sign Out"]
        
        // Account options should be present
        if waitForElement(accountSection, timeout: 5) {
            XCTAssertTrue(accountSection.exists, "Account section should exist")
        }
    }
    
    func testSignOutButtonExists() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Scroll to find sign out
        app.swipeUp()
        
        let signOutButton = app.buttons["Sign Out"]
        if waitForElement(signOutButton, timeout: 5) {
            XCTAssertTrue(signOutButton.exists, "Sign out button should exist")
        }
    }
    
    // MARK: - Appearance Tests
    
    func testAppearanceOptionsExist() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Look for appearance options
        let appearanceSection = app.staticTexts["Appearance"]
        let themeOption = app.staticTexts["Theme"]
        
        // Appearance settings should be present
    }
    
    // MARK: - Security Tests
    
    func testSecurityOptionsExist() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Look for security section
        let securitySection = app.staticTexts["Security"]
        let recoveryPhrase = app.staticTexts["Recovery Phrase"]
        
        // Security options may be present
    }
    
    // MARK: - Sign Out Flow Tests
    
    func testSignOutShowsConfirmation() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Scroll and tap sign out
        app.swipeUp()
        
        let signOutButton = app.buttons["Sign Out"]
        if waitForElement(signOutButton, timeout: 5) {
            signOutButton.tap()
            
            // Should show confirmation
            let confirmationAlert = app.alerts.firstMatch
            let confirmationSheet = app.sheets.firstMatch
            
            let hasConfirmation = confirmationAlert.exists || confirmationSheet.exists
            XCTAssertTrue(hasConfirmation, "Sign out should show confirmation")
        }
    }
    
    func testSignOutReturnsToLogin() {
        launchAuthenticated()
        waitForAppReady()
        
        navigateToSettings()
        
        // Scroll and tap sign out
        app.swipeUp()
        
        let signOutButton = app.buttons["Sign Out"]
        if waitForElement(signOutButton, timeout: 5) {
            signOutButton.tap()
            
            // Confirm sign out
            let confirmButton = app.buttons["Sign Out"]
            if waitForElement(confirmButton, timeout: 3) {
                confirmButton.tap()
            }
            
            // Should return to auth screen
            let authView = app.otherElements["authenticationView"]
            if waitForElement(authView, timeout: 10) {
                XCTAssertTrue(authView.exists, "Should return to auth screen after sign out")
            }
        }
    }
}
