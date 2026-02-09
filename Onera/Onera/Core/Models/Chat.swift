//
//  Chat.swift
//  Onera
//
//  Chat domain models
//

import Foundation

// MARK: - Chat

struct Chat: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    /// The folder this chat belongs to (nil = no folder)
    var folderId: String?
    
    /// Whether the chat is pinned to the top
    var pinned: Bool
    
    /// Whether the chat is archived
    var archived: Bool
    
    /// The chat's symmetric encryption key (only in memory, never persisted)
    var encryptionKey: Data?
    
    /// Full message tree for branch persistence (only in memory, restored from encrypted data)
    /// Contains all messages including alternative branches from regeneration/edits.
    var allMessages: [String: Message]?
    
    /// Whether this chat has been persisted to the server
    var isPersisted: Bool {
        !id.isEmpty
    }
    
    init(
        id: String = "",  // Empty = not persisted yet
        title: String = "New Chat",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        folderId: String? = nil,
        pinned: Bool = false,
        archived: Bool = false,
        encryptionKey: Data? = nil,
        allMessages: [String: Message]? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderId = folderId
        self.pinned = pinned
        self.archived = archived
        self.encryptionKey = encryptionKey
        self.allMessages = allMessages
    }
    
    var isEmpty: Bool {
        messages.isEmpty
    }
    
    var lastMessage: Message? {
        messages.last
    }
    
    var previewText: String {
        lastMessage?.content.truncatedAtWord(to: 50) ?? "No messages"
    }
}

// MARK: - Chat Summary (for list display)

struct ChatSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    
    var group: ChatGroup {
        ChatGroup.for(date: updatedAt)
    }
    
    init(
        id: String,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        folderId: String? = nil,
        pinned: Bool = false,
        archived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderId = folderId
        self.pinned = pinned
        self.archived = archived
    }
}

// MARK: - Chat Group (for sidebar grouping)

enum ChatGroup: Hashable, Comparable, Sendable {
    case today
    case yesterday
    case previousWeek
    case previousMonth
    case older(monthYear: String)
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .previousWeek: return "Previous 7 Days"
        case .previousMonth: return "Previous 30 Days"
        case .older(let monthYear): return monthYear
        }
    }
    
    private var sortOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .previousWeek: return 2
        case .previousMonth: return 3
        case .older: return 4
        }
    }
    
    static func < (lhs: ChatGroup, rhs: ChatGroup) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
    
    static func `for`(date: Date) -> ChatGroup {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date >= weekAgo {
            return .previousWeek
        } else if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now),
                  date >= monthAgo {
            return .previousMonth
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return .older(monthYear: formatter.string(from: date))
        }
    }
}

// MARK: - Mock Data

#if DEBUG
extension Chat {
    static func mock(
        id: String = UUID().uuidString,
        title: String = "Mock Chat",
        messages: [Message] = [],
        folderId: String? = nil
    ) -> Chat {
        Chat(
            id: id,
            title: title,
            messages: messages,
            createdAt: Date(),
            updatedAt: Date(),
            folderId: folderId
        )
    }
    
    static var mockWithMessages: Chat {
        Chat(
            title: "Sample Conversation",
            messages: [
                .mock(role: .user, content: "Hello! Can you help me with Swift?"),
                .mock(role: .assistant, content: "Of course! I'd be happy to help with Swift. What would you like to know?"),
                .mock(role: .user, content: "How do I use async/await?"),
                .mock(role: .assistant, content: "Async/await in Swift makes asynchronous code much easier to read and write.\n\nHere's a simple example:\n\n```swift\nfunc fetchData() async throws -> Data {\n    let url = URL(string: \"https://api.example.com/data\")!\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return data\n}\n```")
            ]
        )
    }
}

extension ChatSummary {
    static func mock(
        id: String = UUID().uuidString,
        title: String = "Mock Chat",
        daysAgo: Int = 0,
        folderId: String? = nil
    ) -> ChatSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return ChatSummary(
            id: id,
            title: title,
            createdAt: date,
            updatedAt: date,
            folderId: folderId
        )
    }
}
#endif
