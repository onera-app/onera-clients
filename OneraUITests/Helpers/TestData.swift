//
//  TestData.swift
//  OneraUITests
//
//  Mock data factories for UI tests
//

import Foundation

enum TestData {
    
    // MARK: - User Data
    
    enum User {
        static let testEmail = "test@example.com"
        static let testName = "Test User"
    }
    
    // MARK: - Chat Data
    
    enum Chat {
        static let sampleUserMessage = "Hello, can you help me with a Swift question?"
        static let sampleAssistantResponse = "Of course! I'd be happy to help with Swift. What would you like to know?"
        static let longUserMessage = "I'm working on a complex SwiftUI application and I need help understanding how to properly manage state across multiple views. Can you explain the difference between @State, @Binding, @StateObject, and @ObservedObject?"
        static let codeQuestion = "How do I implement a custom modifier in SwiftUI?"
    }
    
    // MARK: - Note Data
    
    enum Note {
        static let sampleTitle = "Test Note Title"
        static let sampleContent = "This is the content of a test note. It contains some text for testing purposes."
        static let updatedTitle = "Updated Note Title"
        static let updatedContent = "This content has been updated for testing."
    }
    
    // MARK: - Folder Data
    
    enum Folder {
        static let sampleName = "Test Folder"
        static let renamedName = "Renamed Folder"
        static let subfolderName = "Subfolder"
    }
    
    // MARK: - Timeouts
    
    enum Timeout {
        static let short: TimeInterval = 5
        static let medium: TimeInterval = 10
        static let long: TimeInterval = 30
        static let streaming: TimeInterval = 60
    }
}
