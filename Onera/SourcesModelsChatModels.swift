//
//  ChatModels.swift
//  Onera
//
//  Chat data models
//

import Foundation

// MARK: - Message Models

struct Message: Identifiable, Equatable, Codable {
    let id: String
    let role: MessageRole
    var content: String
    let createdAt: Date
    var attachments: [Attachment]
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct Attachment: Identifiable, Equatable, Codable {
    let id: String
    let type: AttachmentType
    let data: Data
    let mimeType: String
    
    init(id: String = UUID().uuidString, type: AttachmentType, data: Data, mimeType: String) {
        self.id = id
        self.type = type
        self.data = data
        self.mimeType = mimeType
    }
}

enum AttachmentType: String, Codable, Equatable {
    case image
    case file
}

// MARK: - Chat Models

struct Chat: Identifiable, Equatable {
    let id: String
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    // Encryption metadata (not persisted in plaintext)
    var chatKey: Data?
    
    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        chatKey: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chatKey = chatKey
    }
}

// MARK: - Chat Grouping

enum ChatGroup: Hashable {
    case today
    case yesterday
    case previousSevenDays
    case previousThirtyDays
    case older(month: String)
    
    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .previousSevenDays:
            return "Previous 7 Days"
        case .previousThirtyDays:
            return "Previous 30 Days"
        case .older(let month):
            return month
        }
    }
    
    static func group(for date: Date) -> ChatGroup {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date >= sevenDaysAgo {
            return .previousSevenDays
        } else if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now),
                  date >= thirtyDaysAgo {
            return .previousThirtyDays
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return .older(month: formatter.string(from: date))
        }
    }
}

// MARK: - Chat State for Encoding

struct ChatData: Codable {
    let messages: [Message]
    
    init(messages: [Message]) {
        self.messages = messages
    }
}
