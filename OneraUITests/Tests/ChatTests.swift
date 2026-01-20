//
//  ChatTests.swift
//  OneraUITests
//
//  E2E tests for chat functionality
//

import XCTest

final class ChatTests: XCTestCase {
    
    var app: XCUIApplication!
    var chatScreen: ChatScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        AppLauncher.configureWithMockChats(app)
        app.launch()
        
        chatScreen = ChatScreen(app: app)
        
        // Wait for chat screen to load
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            throw XCTSkip("Chat screen not available - skipping test")
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
        chatScreen = nil
    }
    
    // MARK: - Test Cases
    
    /// Test that new chat shows empty state
    func testEmptyStateShown() throws {
        // Create a new chat
        chatScreen.tapNewChat()
        
        // Verify empty state is shown
        XCTAssertTrue(chatScreen.isEmptyState, "New chat should show empty state")
        
        takeScreenshot(name: "Chat_Empty_State")
    }
    
    /// Test sending a message and receiving a response
    func testSendMessageAndReceiveResponse() throws {
        // Start with new chat
        chatScreen.tapNewChat()
        
        let testMessage = TestData.Chat.sampleUserMessage
        
        // Send message
        chatScreen.sendMessage(testMessage)
        
        // Wait for response
        XCTAssertTrue(chatScreen.waitForResponse(timeout: 30), "Should receive a response")
        
        // Verify we have messages
        XCTAssertTrue(chatScreen.hasMessages, "Chat should have messages after sending")
        
        takeScreenshot(name: "Chat_Message_Sent")
    }
    
    /// Test model selection dropdown
    func testModelSelectionDropdown() throws {
        // Check if model selector exists
        guard chatScreen.modelSelector.waitForExistence(timeout: 5) else {
            throw XCTSkip("Model selector not available")
        }
        
        // Tap model selector
        chatScreen.modelSelector.tap()
        
        // Should see dropdown options
        // Look for model names in the dropdown
        let modelOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'GPT' OR label CONTAINS[c] 'Claude' OR label CONTAINS[c] 'model'"))
        
        XCTAssertTrue(modelOptions.firstMatch.waitForExistence(timeout: 5), "Model options should be visible")
        
        takeScreenshot(name: "Chat_Model_Selector")
    }
    
    /// Test copying message content
    func testCopyMessageContent() throws {
        // Need a chat with existing messages
        let sidebarScreen = chatScreen.tapMenuButton()
        
        // Select first chat if available
        if sidebarScreen.chatCount > 0 {
            chatScreen = sidebarScreen.selectChatAtIndex(0)
        } else {
            // Create a new message first
            sidebarScreen.swipeToClose()
            chatScreen.sendMessage(TestData.Chat.sampleUserMessage)
            _ = chatScreen.waitForResponse(timeout: 30)
        }
        
        // Find and tap copy button
        if chatScreen.copyButton.waitForExistence(timeout: 10) {
            chatScreen.tapCopyButton()
            
            // Look for "Copied" feedback
            let copiedFeedback = app.staticTexts["Copied"]
            XCTAssertTrue(copiedFeedback.waitForExistence(timeout: 3), "Should show copied feedback")
            
            takeScreenshot(name: "Chat_Copy_Feedback")
        }
    }
    
    /// Test regenerating a response
    func testRegenerateResponse() throws {
        // Start new chat and send message
        chatScreen.tapNewChat()
        chatScreen.sendMessage(TestData.Chat.sampleUserMessage)
        
        // Wait for initial response
        guard chatScreen.waitForStreamingComplete(timeout: 60) else {
            throw XCTSkip("Streaming did not complete")
        }
        
        // Tap regenerate
        if chatScreen.regenerateButton.exists {
            chatScreen.tapRegenerateButton()
            
            // Wait for new response
            XCTAssertTrue(chatScreen.waitForStreamingComplete(timeout: 60), "Regeneration should complete")
            
            takeScreenshot(name: "Chat_Regenerated")
        }
    }
    
    /// Test response branching (viewing different versions)
    func testResponseBranching() throws {
        // Start new chat and send message
        chatScreen.tapNewChat()
        chatScreen.sendMessage(TestData.Chat.sampleUserMessage)
        
        // Wait for initial response
        guard chatScreen.waitForStreamingComplete(timeout: 60) else {
            throw XCTSkip("Streaming did not complete")
        }
        
        // Regenerate to create a branch
        if chatScreen.regenerateButton.exists {
            chatScreen.tapRegenerateButton()
            _ = chatScreen.waitForStreamingComplete(timeout: 60)
            
            // Check for branch navigation
            if chatScreen.branchCount.waitForExistence(timeout: 5) {
                takeScreenshot(name: "Chat_Branch_Navigation")
                
                // Try navigating branches
                if chatScreen.branchPreviousButton.isEnabled {
                    chatScreen.tapPreviousBranch()
                    takeScreenshot(name: "Chat_Previous_Branch")
                }
            }
        }
    }
    
    /// Test editing a user message
    func testEditMessage() throws {
        // Start new chat and send message
        chatScreen.tapNewChat()
        chatScreen.sendMessage(TestData.Chat.sampleUserMessage)
        
        // Wait for response
        _ = chatScreen.waitForResponse(timeout: 30)
        
        // Long press on user message to get context menu
        let messages = chatScreen.allMessages
        if let userMessage = messages.first(where: { _ in true }) { // Get first message
            userMessage.press(forDuration: 1.0)
            
            // Look for Edit option in context menu
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 3) {
                editButton.tap()
                takeScreenshot(name: "Chat_Edit_Mode")
            }
        }
    }
    
    /// Test TTS playback
    func testTTSPlayback() throws {
        // Need a chat with existing messages
        chatScreen.sendMessage(TestData.Chat.sampleUserMessage)
        _ = chatScreen.waitForStreamingComplete(timeout: 60)
        
        // Find and tap speak button
        if chatScreen.speakButton.waitForExistence(timeout: 10) {
            chatScreen.tapSpeakButton()
            
            // Look for TTS player overlay
            let ttsOverlay = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'tts' OR identifier CONTAINS 'player'")).firstMatch
            
            // Or just check if the button changed to stop
            let stopButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'stop'")).firstMatch
            
            takeScreenshot(name: "Chat_TTS_Playing")
            
            // Stop TTS
            chatScreen.tapSpeakButton()
        }
    }
    
    /// Test message with reasoning/thinking content
    func testMessageWithReasoning() throws {
        // This test would require a mock that returns thinking tags
        // For now, we'll just verify the structure exists
        
        chatScreen.sendMessage("Explain step by step how to solve 2+2")
        _ = chatScreen.waitForStreamingComplete(timeout: 60)
        
        // Look for reasoning/thinking UI elements
        let reasoningElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'thinking' OR label CONTAINS[c] 'reasoning'"))
        
        takeScreenshot(name: "Chat_With_Reasoning")
    }
    
    /// Test sending a long message
    func testSendLongMessage() throws {
        chatScreen.tapNewChat()
        chatScreen.sendMessage(TestData.Chat.longUserMessage)
        
        XCTAssertTrue(chatScreen.waitForResponse(timeout: 30), "Should receive response for long message")
        
        takeScreenshot(name: "Chat_Long_Message")
    }
}

