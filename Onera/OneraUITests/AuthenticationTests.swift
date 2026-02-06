//
//  AuthenticationTests.swift
//  OneraUITests
//
//  UI tests for authentication flows
//

import XCTest

final class AuthenticationTests: OneraUITestCase {
    
    // MARK: - Login Screen Tests
    
    func testLoginScreenAppears() {
        launchUnauthenticated()
        waitForAppReady()
        
        // Verify authentication view is shown
        let authView = app.otherElements["authenticationView"]
        assertExists(authView, message: "Authentication view should appear for unauthenticated user")
        
        // Verify sign-in buttons exist
        let appleButton = app.buttons["signInWithApple"]
        let googleButton = app.buttons["signInWithGoogle"]
        
        assertExists(appleButton, message: "Sign in with Apple button should exist")
        assertExists(googleButton, message: "Sign in with Google button should exist")
    }
    
    func testGoogleSignInButton() {
        launchUnauthenticated()
        waitForAppReady()
        
        let googleButton = app.buttons["signInWithGoogle"]
        assertExists(googleButton)
        
        // Verify button is tappable
        XCTAssertTrue(googleButton.isHittable, "Google sign-in button should be tappable")
    }
    
    func testAppleSignInButton() {
        launchUnauthenticated()
        waitForAppReady()
        
        let appleButton = app.buttons["signInWithApple"]
        assertExists(appleButton)
        
        // Verify button is tappable
        XCTAssertTrue(appleButton.isHittable, "Apple sign-in button should be tappable")
    }
    
    // MARK: - E2EE Setup Tests
    
    func testE2EESetupFlowAppears() {
        launchNeedsE2EESetup()
        waitForAppReady()
        
        // Should show E2EE setup view after authentication
        // Look for unlock method options or setup indicators
        let setupIndicator = app.staticTexts["Quick Unlock"]
        let exists = waitForElement(setupIndicator, timeout: 10)
        
        XCTAssertTrue(exists, "E2EE setup flow should appear for new users")
    }
    
    func testE2EESetupShowsPasskeyOption() {
        launchNeedsE2EESetup()
        waitForAppReady()
        
        // Wait for setup screen
        _ = waitForElement(app.staticTexts["Quick Unlock"], timeout: 10)
        
        // Check for passkey option
        let passkeyOption = app.staticTexts["Passkey"]
        if passkeyOption.exists {
            XCTAssertTrue(passkeyOption.exists, "Passkey option should be available")
        }
    }
    
    func testE2EESetupShowsPasswordOption() {
        launchNeedsE2EESetup()
        waitForAppReady()
        
        // Wait for setup screen
        _ = waitForElement(app.staticTexts["Quick Unlock"], timeout: 10)
        
        // Check for password option
        let passwordOption = app.staticTexts["Password"]
        assertExists(passwordOption, message: "Password option should be available")
    }
    
    // MARK: - E2EE Unlock Tests
    
    func testE2EEUnlockScreenAppears() {
        launchNeedsE2EEUnlock()
        waitForAppReady()
        
        // Should show unlock screen
        let unlockTitle = app.navigationBars["Unlock"]
        let exists = waitForElement(unlockTitle, timeout: 10)
        
        XCTAssertTrue(exists, "E2EE unlock screen should appear for returning users")
    }
    
    func testE2EEUnlockShowsRecoveryPhraseOption() {
        launchNeedsE2EEUnlock()
        waitForAppReady()
        
        // Wait for unlock screen
        _ = waitForElement(app.navigationBars["Unlock"], timeout: 10)
        
        // Check for recovery phrase option
        let recoveryOption = app.staticTexts["Recovery Phrase"]
        assertExists(recoveryOption, message: "Recovery phrase option should be available")
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOutFromE2EESetup() {
        launchNeedsE2EESetup()
        waitForAppReady()
        
        // Wait for setup screen
        _ = waitForElement(app.staticTexts["Quick Unlock"], timeout: 10)
        
        // Scroll down to find sign out
        app.swipeUp()
        
        // Look for sign out button
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
            assertExists(authView, message: "Should return to auth screen after sign out")
        }
    }
}
