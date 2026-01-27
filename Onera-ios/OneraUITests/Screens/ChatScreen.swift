//
//  ChatScreen.swift
//  OneraUITests
//
//  Page Object for the Chat screen
//

import XCTest

struct ChatScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var messageInput: XCUIElement {
        app.textFields["messageInput"]
    }
    
    var sendButton: XCUIElement {
        app.buttons["sendButton"]
    }
    
    var modelSelector: XCUIElement {
        app.buttons["modelSelector"]
    }
    
    var menuButton: XCUIElement {
        app.buttons["menuButton"]
    }
    
    var newChatButton: XCUIElement {
        app.buttons["newChatButton"]
    }
    
    var emptyStateTitle: XCUIElement {
        app.staticTexts["What's on your mind?"]
    }
    
    // MARK: - Message Elements
    
    func message(id: String) -> XCUIElement {
        app.otherElements["message_\(id)"]
    }
    
    func messageByIndex(_ index: Int) -> XCUIElement {
        app.otherElements.matching(identifier: "message_").element(boundBy: index)
    }
    
    var allMessages: [XCUIElement] {
        app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'message_'")).allElementsBoundByIndex
    }
    
    // MARK: - Action Button Elements
    
    var copyButton: XCUIElement {
        app.buttons["copyButton"]
    }
    
    var regenerateButton: XCUIElement {
        app.buttons["regenerateButton"]
    }
    
    var speakButton: XCUIElement {
        app.buttons["speakButton"]
    }
    
    var branchPreviousButton: XCUIElement {
        app.buttons["branchPrevious"]
    }
    
    var branchNextButton: XCUIElement {
        app.buttons["branchNext"]
    }
    
    var branchCount: XCUIElement {
        app.staticTexts["branchCount"]
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        messageInput.waitForExistence(timeout: 5)
    }
    
    var isEmptyState: Bool {
        emptyStateTitle.waitForExistence(timeout: 3)
    }
    
    var hasMessages: Bool {
        !allMessages.isEmpty
    }
    
    var messageCount: Int {
        allMessages.count
    }
    
    // MARK: - Actions
    
    @discardableResult
    func typeMessage(_ text: String) -> ChatScreen {
        messageInput.tap()
        messageInput.typeText(text)
        return self
    }
    
    @discardableResult
    func sendMessage(_ text: String) -> ChatScreen {
        typeMessage(text)
        sendButton.tap()
        return self
    }
    
    @discardableResult
    func tapMenuButton() -> SidebarScreen {
        menuButton.tap()
        return SidebarScreen(app: app)
    }
    
    @discardableResult
    func tapNewChat() -> ChatScreen {
        newChatButton.tap()
        return self
    }
    
    @discardableResult
    func tapCopyButton() -> ChatScreen {
        copyButton.tap()
        return self
    }
    
    @discardableResult
    func tapRegenerateButton() -> ChatScreen {
        regenerateButton.tap()
        return self
    }
    
    @discardableResult
    func tapSpeakButton() -> ChatScreen {
        speakButton.tap()
        return self
    }
    
    @discardableResult
    func tapPreviousBranch() -> ChatScreen {
        branchPreviousButton.tap()
        return self
    }
    
    @discardableResult
    func tapNextBranch() -> ChatScreen {
        branchNextButton.tap()
        return self
    }
    
    func waitForResponse(timeout: TimeInterval = 30) -> Bool {
        // Wait for message count to increase (indicates response received)
        let initialCount = messageCount
        let predicate = NSPredicate { _, _ in
            self.messageCount > initialCount
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    
    func waitForStreamingComplete(timeout: TimeInterval = 60) -> Bool {
        // Wait for regenerate button to appear (indicates streaming is done)
        regenerateButton.waitForExistence(timeout: timeout)
    }
}
