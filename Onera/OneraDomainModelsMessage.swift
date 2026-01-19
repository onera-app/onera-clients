//
//  Message.swift
//  Onera
//
//  Message domain models
//

import Foundation

// MARK: - Message

struct Message: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let role: MessageRole
    var content: String
    let createdAt: Date
    var attachments: [Attachment]
    
    /// Indicates if the message is still being streamed
    var isStreaming: Bool
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        attachments: [Attachment] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
        self.isStreaming = isStreaming
    }
    
    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
    var isSystem: Bool { role == .system }
}

// MARK: - Message Role

enum MessageRole: String, Codable, Equatable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Attachment

struct Attachment: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let type: AttachmentType
    let data: Data
    let mimeType: String
    let fileName: String?
    
    init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        data: Data,
        mimeType: String,
        fileName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }
}

enum AttachmentType: String, Codable, Equatable, Sendable {
    case image
    case file
}

// MARK: - Chat Data (for serialization)

struct ChatData: Codable, Sendable {
    let messages: [Message]
    let version: Int
    
    init(messages: [Message], version: Int = 1) {
        self.messages = messages
        self.version = version
    }
}

// MARK: - Mock Data

#if DEBUG
extension Message {
    static func mock(
        id: String = UUID().uuidString,
        role: MessageRole = .user,
        content: String = "Hello, world!"
    ) -> Message {
        Message(
            id: id,
            role: role,
            content: content,
            createdAt: Date(),
            attachments: [],
            isStreaming: false
        )
    }
    
    static var mockUserMessage: Message {
        .mock(role: .user, content: "Can you help me with a Swift question?")
    }
    
    static var mockAssistantMessage: Message {
        .mock(role: .assistant, content: "Of course! I'd be happy to help. What's your question?")
    }
    
    static var mockStreamingMessage: Message {
        Message(
            role: .assistant,
            content: "I'm thinking...",
            isStreaming: true
        )
    }
}
#endif
