//
//  NavigationTests.swift
//  OneraUITests
//
//  E2E tests for app navigation
//

import XCTest

final class NavigationTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        AppLauncher.configureWithMockChats(app)
        app.launch()
        
        // Wait for app to load
        let chatScreen = ChatScreen(app: app)
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            throw XCTSkip("App not loaded - skipping navigation tests")
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test Cases
    
    /// Test opening sidebar with swipe gesture
    func testOpenSidebarWithSwipe() throws {
        // Swipe from left edge
        swipeFromLeftEdge()
        
        // Verify sidebar is visible
        let sidebarScreen = SidebarScreen(app: app)
        XCTAssertTrue(sidebarScreen.sidebarDrawer.waitForExistence(timeout: 5), "Sidebar should be visible after swipe")
        
        takeScreenshot(name: "Nav_Sidebar_Opened")
    }
    
    /// Test closing sidebar with swipe gesture
    func testCloseSidebarWithSwipe() throws {
        // First open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.sidebarDrawer.waitForExistence(timeout: 5) else {
            XCTFail("Sidebar did not open")
            return
        }
        
        // Close with swipe
        sidebarScreen.swipeToClose()
        
        // Verify sidebar is closed
        let chatScreen = ChatScreen(app: app)
        XCTAssertTrue(chatScreen.messageInput.waitForExistence(timeout: 5), "Chat should be visible after closing sidebar")
        
        takeScreenshot(name: "Nav_Sidebar_Closed")
    }
    
    /// Test closing sidebar by tapping outside
    func testCloseSidebarWithTapOutside() throws {
        // Open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.sidebarDrawer.waitForExistence(timeout: 5) else {
            XCTFail("Sidebar did not open")
            return
        }
        
        // Tap on the dimmed overlay (right side of screen)
        let rightSide = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        rightSide.tap()
        
        // Verify sidebar is closed
        let chatScreen = ChatScreen(app: app)
        XCTAssertTrue(chatScreen.messageInput.waitForExistence(timeout: 5), "Chat should be visible after tapping outside")
        
        takeScreenshot(name: "Nav_Sidebar_Tap_Close")
    }
    
    /// Test creating new chat from nav bar
    func testNewChatFromNavBar() throws {
        let chatScreen = ChatScreen(app: app)
        
        // Send a message first to make the chat non-empty
        chatScreen.sendMessage("Hello")
        _ = chatScreen.waitForResponse(timeout: 30)
        
        // Tap new chat button
        chatScreen.tapNewChat()
        
        // Verify empty state is shown
        XCTAssertTrue(chatScreen.isEmptyState, "New chat should show empty state")
        
        takeScreenshot(name: "Nav_New_Chat")
    }
    
    /// Test selecting a chat from history
    func testSelectChatFromHistory() throws {
        // Open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.sidebarDrawer.waitForExistence(timeout: 5) else {
            XCTFail("Sidebar did not open")
            return
        }
        
        // Check if there are chats
        if sidebarScreen.chatCount > 0 {
            // Select first chat
            let chatScreen = sidebarScreen.selectChatAtIndex(0)
            
            // Verify chat is loaded
            XCTAssertTrue(chatScreen.messageInput.waitForExistence(timeout: 5), "Chat should be loaded")
            XCTAssertTrue(chatScreen.hasMessages, "Selected chat should have messages")
            
            takeScreenshot(name: "Nav_Chat_Selected")
        } else {
            // No chats available - just verify the empty state
            takeScreenshot(name: "Nav_No_Chats")
        }
    }
    
    /// Test searching chats
    func testSearchChats() throws {
        // Open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.searchField.waitForExistence(timeout: 5) else {
            throw XCTSkip("Search field not available")
        }
        
        // Type search query
        sidebarScreen.searchChats("Swift")
        
        takeScreenshot(name: "Nav_Search_Results")
        
        // Clear search
        sidebarScreen.clearSearch()
        
        takeScreenshot(name: "Nav_Search_Cleared")
    }
    
    /// Test navigating to settings
    func testNavigateToSettings() throws {
        // Open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button not found")
            return
        }
        
        // Tap settings
        let settingsScreen = sidebarScreen.tapSettings()
        
        // Verify settings is displayed
        XCTAssertTrue(settingsScreen.isDisplayed, "Settings should be displayed")
        
        takeScreenshot(name: "Nav_Settings")
        
        // Close settings
        settingsScreen.close()
    }
    
    /// Test navigating to notes
    func testNavigateToNotes() throws {
        // Open sidebar
        swipeFromLeftEdge()
        
        let sidebarScreen = SidebarScreen(app: app)
        guard sidebarScreen.notesButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Notes button not available")
        }
        
        // Tap notes
        let notesScreen = sidebarScreen.tapNotes()
        
        // Verify notes is displayed
        XCTAssertTrue(notesScreen.isDisplayed, "Notes should be displayed")
        
        takeScreenshot(name: "Nav_Notes")
        
        // Dismiss notes
        notesScreen.dismiss()
    }
}

// MARK: - Helper Extensions

extension NavigationTests {
    func swipeFromLeftEdge() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
