//
//  AuthScreen.swift
//  OneraUITests
//
//  Page Object for the Authentication screen
//

import XCTest

struct AuthScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var signInWithAppleButton: XCUIElement {
        app.buttons["signInWithApple"]
    }
    
    var signInWithGoogleButton: XCUIElement {
        app.buttons["signInWithGoogle"]
    }
    
    var loadingIndicator: XCUIElement {
        app.activityIndicators.firstMatch
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        // Check if either sign-in button is visible
        signInWithAppleButton.waitForExistence(timeout: 5) ||
        signInWithGoogleButton.waitForExistence(timeout: 5)
    }
    
    // MARK: - Actions
    
    @discardableResult
    func tapSignInWithApple() -> AuthScreen {
        signInWithAppleButton.tap()
        return self
    }
    
    @discardableResult
    func tapSignInWithGoogle() -> AuthScreen {
        signInWithGoogleButton.tap()
        return self
    }
    
    func waitForLoading(timeout: TimeInterval = 10) -> Bool {
        // Wait for loading to disappear
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
