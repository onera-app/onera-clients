//
//  AppLauncher.swift
//  OneraUITests
//
//  App launch configuration for different test scenarios
//

import XCTest

enum AppLauncher {
    
    /// Configure app for UI testing
    static func configureForTesting(_ app: XCUIApplication) {
        // Basic UI testing flag
        app.launchArguments.append("--uitesting")
        
        // Disable animations for faster tests
        app.launchArguments.append("--disable-animations")
        
        // Reset state for clean tests
        app.launchArguments.append("--reset-state")
    }
    
    /// Configure app as authenticated user
    static func configureAsAuthenticated(_ app: XCUIApplication) {
        configureForTesting(app)
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--skip-biometrics")
    }
    
    /// Configure app as unauthenticated user
    static func configureAsUnauthenticated(_ app: XCUIApplication) {
        configureForTesting(app)
        app.launchArguments.append("--unauthenticated")
    }
    
    /// Configure app for new user (needs E2EE setup)
    static func configureAsNewUser(_ app: XCUIApplication) {
        configureForTesting(app)
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--needs-e2ee-setup")
    }
    
    /// Configure app for returning user (needs E2EE unlock)
    static func configureForE2EEUnlock(_ app: XCUIApplication) {
        configureForTesting(app)
        app.launchArguments.append("--authenticated")
        app.launchArguments.append("--needs-e2ee-unlock")
    }
    
    /// Configure with mock chat data
    static func configureWithMockChats(_ app: XCUIApplication) {
        configureAsAuthenticated(app)
        app.launchArguments.append("--mock-chats")
    }
    
    /// Configure with mock notes data
    static func configureWithMockNotes(_ app: XCUIApplication) {
        configureAsAuthenticated(app)
        app.launchArguments.append("--mock-notes")
    }
}
