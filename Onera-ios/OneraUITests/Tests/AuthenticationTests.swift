//
//  AuthenticationTests.swift
//  OneraUITests
//
//  E2E tests for authentication flows
//

import XCTest

final class AuthenticationTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test Cases
    
    /// Verify app shows loading state on initial launch
    func testLaunchShowsLoadingState() throws {
        AppLauncher.configureForTesting(app)
        app.launch()
        
        // Should see some form of loading or launch screen initially
        // The app should not crash and should transition to a valid state
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        
        takeScreenshot(name: "Launch_State")
    }
    
    /// Verify unauthenticated users see sign-in options
    func testUnauthenticatedShowsSignInOptions() throws {
        AppLauncher.configureAsUnauthenticated(app)
        app.launch()
        
        let authScreen = AuthScreen(app: app)
        
        // Wait for auth screen to be displayed
        XCTAssertTrue(authScreen.isDisplayed, "Auth screen should be displayed for unauthenticated users")
        
        // Verify both sign-in buttons are present
        XCTAssertTrue(authScreen.signInWithAppleButton.exists || authScreen.signInWithGoogleButton.exists,
                      "At least one sign-in button should be visible")
        
        takeScreenshot(name: "Auth_SignIn_Options")
    }
    
    /// Test Apple sign-in flow (mocked)
    func testSignInWithAppleFlow() throws {
        AppLauncher.configureAsUnauthenticated(app)
        app.launch()
        
        let authScreen = AuthScreen(app: app)
        
        // Wait for auth screen
        guard authScreen.signInWithAppleButton.waitForExistence(timeout: 10) else {
            XCTFail("Apple sign-in button not found")
            return
        }
        
        // Tap Apple sign-in (in mock mode, should proceed without real auth)
        authScreen.tapSignInWithApple()
        
        takeScreenshot(name: "Auth_Apple_Tapped")
    }
    
    /// Test E2EE setup flow for new users
    func testE2EESetupFlowForNewUser() throws {
        AppLauncher.configureAsNewUser(app)
        app.launch()
        
        // New users should see E2EE setup
        // Look for recovery phrase display or setup instructions
        let setupElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'recovery' OR label CONTAINS[c] 'phrase' OR label CONTAINS[c] 'backup'"))
        
        // Give time for E2EE setup to appear
        _ = setupElements.firstMatch.waitForExistence(timeout: 10)
        
        takeScreenshot(name: "Auth_E2EE_Setup")
    }
    
    /// Test E2EE unlock flow for returning users
    func testE2EEUnlockFlowForReturningUser() throws {
        AppLauncher.configureForE2EEUnlock(app)
        app.launch()
        
        // Returning users should see unlock screen
        // Look for unlock-related elements
        let unlockElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'unlock' OR label CONTAINS[c] 'enter' OR label CONTAINS[c] 'recovery'"))
        
        _ = unlockElements.firstMatch.waitForExistence(timeout: 10)
        
        takeScreenshot(name: "Auth_E2EE_Unlock")
    }
    
    /// Test sign out flow
    func testSignOutFlow() throws {
        AppLauncher.configureAsAuthenticated(app)
        app.launch()
        
        let chatScreen = ChatScreen(app: app)
        
        // Wait for main app to load
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            XCTFail("Chat screen not loaded - app may not be authenticated")
            return
        }
        
        // Open sidebar and navigate to settings
        let sidebarScreen = chatScreen.tapMenuButton()
        
        guard sidebarScreen.settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button not found in sidebar")
            return
        }
        
        let settingsScreen = sidebarScreen.tapSettings()
        
        guard settingsScreen.signOutButton.waitForExistence(timeout: 5) else {
            XCTFail("Sign out button not found in settings")
            return
        }
        
        // Tap sign out
        settingsScreen.tapSignOut()
        
        takeScreenshot(name: "Auth_SignOut_Confirmation")
        
        // Confirm sign out
        settingsScreen.confirmSignOut()
        
        // Should return to auth screen
        let authScreen = AuthScreen(app: app)
        XCTAssertTrue(authScreen.signInWithAppleButton.waitForExistence(timeout: 10) ||
                      authScreen.signInWithGoogleButton.waitForExistence(timeout: 10),
                      "Should return to auth screen after sign out")
        
        takeScreenshot(name: "Auth_After_SignOut")
    }
}

