//
//  SettingsScreen.swift
//  OneraUITests
//
//  Page Object for the Settings screen
//

import XCTest

struct SettingsScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var signOutButton: XCUIElement {
        app.buttons["signOutButton"]
    }
    
    var recoveryPhraseButton: XCUIElement {
        app.buttons["recoveryPhraseButton"]
    }
    
    var themeSelector: XCUIElement {
        app.buttons["themeSelector"]
    }
    
    var closeButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'xmark' OR identifier CONTAINS 'close'")).firstMatch
    }
    
    var navigationTitle: XCUIElement {
        app.navigationBars["Settings"]
    }
    
    // MARK: - Sign Out Confirmation
    
    var signOutConfirmButton: XCUIElement {
        app.buttons["Sign Out"]
    }
    
    var cancelButton: XCUIElement {
        app.buttons["Cancel"]
    }
    
    // MARK: - Profile Elements
    
    var profileEmail: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS '@'")).firstMatch
    }
    
    var profileName: XCUIElement {
        // Look for user name in the profile section
        app.staticTexts.matching(NSPredicate(format: "NOT (label CONTAINS '@') AND NOT (label CONTAINS 'Settings') AND NOT (label CONTAINS 'Account')")).firstMatch
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        navigationTitle.waitForExistence(timeout: 5) || signOutButton.waitForExistence(timeout: 5)
    }
    
    var hasProfile: Bool {
        profileEmail.exists
    }
    
    // MARK: - Actions
    
    @discardableResult
    func tapSignOut() -> SettingsScreen {
        signOutButton.tap()
        return self
    }
    
    func confirmSignOut() {
        if signOutConfirmButton.waitForExistence(timeout: 3) {
            signOutConfirmButton.tap()
        }
    }
    
    func cancelSignOut() {
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }
    }
    
    @discardableResult
    func tapRecoveryPhrase() -> SettingsScreen {
        recoveryPhraseButton.tap()
        return self
    }
    
    @discardableResult
    func tapThemeSelector() -> SettingsScreen {
        themeSelector.tap()
        return self
    }
    
    func selectTheme(_ theme: String) {
        app.buttons[theme].tap()
    }
    
    @discardableResult
    func close() -> ChatScreen {
        closeButton.tap()
        return ChatScreen(app: app)
    }
}
