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
    
    /// Reasoning/thinking output from AI models (e.g., OpenAI o1, Anthropic extended thinking)
    var reasoning: String?
    
    /// Model used for this message (from web format)
    var model: String?
    
    /// Branching support (from web format)
    var parentId: String?
    var childrenIds: [String]?
    
    /// Edit tracking (from web format)
    var edited: Bool?
    var editedAt: Date?
    
    /// Follow-up suggestions (from web format)
    var followUps: [String]?
    
    // Custom coding keys to match web format (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
        case model
        case parentId
        case childrenIds
        case edited
        case editedAt
        case followUps
        // These are mobile-only, won't be in web data
        case attachments
        case isStreaming
        case reasoning
    }
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        attachments: [Attachment] = [],
        isStreaming: Bool = false,
        reasoning: String? = nil,
        model: String? = nil,
        parentId: String? = nil,
        childrenIds: [String]? = nil,
        edited: Bool? = nil,
        editedAt: Date? = nil,
        followUps: [String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
        self.isStreaming = isStreaming
        self.reasoning = reasoning
        self.model = model
        self.parentId = parentId
        self.childrenIds = childrenIds
        self.edited = edited
        self.editedAt = editedAt
        self.followUps = followUps
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        
        // Handle content - can be String or MessageContent array on web
        if let stringContent = try? container.decode(String.self, forKey: .content) {
            content = stringContent
        } else if let contentArray = try? container.decode([MessageContentItem].self, forKey: .content) {
            // Extract text from content array
            content = contentArray
                .compactMap { item -> String? in
                    if item.type == "text" {
                        return item.text
                    }
                    return nil
                }
                .joined(separator: "\n")
        } else {
            content = ""
        }
        
        // Handle created_at - can be timestamp (Int64) or Date
        if let timestamp = try? container.decode(Int64.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        } else if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        // Optional fields
        model = try container.decodeIfPresent(String.self, forKey: .model)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        childrenIds = try container.decodeIfPresent([String].self, forKey: .childrenIds)
        edited = try container.decodeIfPresent(Bool.self, forKey: .edited)
        
        // Handle editedAt timestamp
        if let editedTimestamp = try? container.decode(Int64.self, forKey: .editedAt) {
            editedAt = Date(timeIntervalSince1970: TimeInterval(editedTimestamp) / 1000)
        } else {
            editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        }
        
        followUps = try container.decodeIfPresent([String].self, forKey: .followUps)
        
        // Mobile-only fields with defaults
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(Int64(createdAt.timeIntervalSince1970 * 1000), forKey: .createdAt)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(childrenIds, forKey: .childrenIds)
        try container.encodeIfPresent(edited, forKey: .edited)
        if let editedAt = editedAt {
            try container.encode(Int64(editedAt.timeIntervalSince1970 * 1000), forKey: .editedAt)
        }
        try container.encodeIfPresent(followUps, forKey: .followUps)
        
        // Only encode mobile fields if they have meaningful values
        if !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
        if isStreaming {
            try container.encode(isStreaming, forKey: .isStreaming)
        }
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
    }
    
    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
    var isSystem: Bool { role == .system }
    
    /// Whether this message has reasoning output
    var hasReasoning: Bool { reasoning != nil && !reasoning!.isEmpty }
}

// MARK: - Message Content Item (for web compatibility)

/// Represents a content item in a multimodal message (matching web's MessageContent)
struct MessageContentItem: Codable, Sendable {
    let type: String
    var text: String?
    var imageUrl: ImageURL?
    var documentUrl: DocumentURL?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
        case documentUrl = "document_url"
    }
    
    struct ImageURL: Codable, Sendable {
        let url: String
    }
    
    struct DocumentURL: Codable, Sendable {
        let url: String
        let fileName: String
        let mimeType: String
        var extractedText: String?
    }
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

/// Chat data structure that's compatible with web format
/// Web stores messages as a tree structure: { currentId: string, messages: Record<string, ChatMessage> }
struct ChatData: Codable, Sendable {
    let messages: [Message]
    
    // For tree structure (web format)
    var currentId: String?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case currentId
    }
    
    init(messages: [Message], currentId: String? = nil) {
        self.messages = messages
        self.currentId = currentId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode messages as dictionary first (web tree format)
        if let messageDict = try? container.decode([String: Message].self, forKey: .messages) {
            // Web format: messages is a Record<string, ChatMessage>
            let currentId = try container.decodeIfPresent(String.self, forKey: .currentId)
            self.currentId = currentId
            
            // Convert tree to linear array by walking up from currentId
            self.messages = ChatData.treeToArray(messages: messageDict, currentId: currentId)
        } else if let messageArray = try? container.decode([Message].self, forKey: .messages) {
            // Mobile format: messages is an array
            self.messages = messageArray
            self.currentId = nil
        } else {
            // Empty messages
            self.messages = []
            self.currentId = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert array back to tree structure for web compatibility
        let (messageDict, currentId) = ChatData.arrayToTree(messages: messages)
        try container.encode(messageDict, forKey: .messages)
        try container.encodeIfPresent(currentId, forKey: .currentId)
    }
    
    /// Convert message tree (dictionary) to linear array by walking from currentId to root
    private static func treeToArray(messages: [String: Message], currentId: String?) -> [Message] {
        guard let targetId = currentId, !messages.isEmpty else {
            // If no currentId, just return all messages sorted by createdAt
            return messages.values.sorted { $0.createdAt < $1.createdAt }
        }
        
        var result: [Message] = []
        var currentMsg = messages[targetId]
        
        // Walk up the tree to root (following parentId)
        while let msg = currentMsg {
            result.insert(msg, at: 0)  // Insert at beginning to maintain order
            if let parentId = msg.parentId {
                currentMsg = messages[parentId]
            } else {
                currentMsg = nil
            }
        }
        
        return result
    }
    
    /// Convert linear array to tree structure for encoding
    private static func arrayToTree(messages: [Message]) -> ([String: Message], String?) {
        guard !messages.isEmpty else {
            return ([:], nil)
        }
        
        var messageDict: [String: Message] = [:]
        var previousId: String? = nil
        
        for var message in messages {
            // Set parentId to previous message
            message.parentId = previousId
            
            // Update previous message's childrenIds
            if let prevId = previousId, var prevMsg = messageDict[prevId] {
                prevMsg.childrenIds = (prevMsg.childrenIds ?? []) + [message.id]
                messageDict[prevId] = prevMsg
            }
            
            messageDict[message.id] = message
            previousId = message.id
        }
        
        // Return with last message as currentId
        return (messageDict, previousId)
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
