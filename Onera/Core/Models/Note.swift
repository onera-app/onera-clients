//
//  Note.swift
//  Onera
//
//  Note domain models
//

import Foundation

// MARK: - Note

struct Note: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var content: String
    var folderId: String?
    var pinned: Bool
    var archived: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        title: String = "Untitled",
        content: String = "",
        folderId: String? = nil,
        pinned: Bool = false,
        archived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.folderId = folderId
        self.pinned = pinned
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var previewText: String {
        if content.isEmpty {
            return "No content"
        }
        return content.truncatedAtWord(to: 100)
    }
}

// MARK: - Note Summary (for list display)

struct NoteSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var group: NoteGroup {
        NoteGroup.for(date: updatedAt)
    }
}

// MARK: - Note Group (for list grouping)

enum NoteGroup: Hashable, Comparable, Sendable {
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
    
    static func < (lhs: NoteGroup, rhs: NoteGroup) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
    
    static func `for`(date: Date) -> NoteGroup {
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

// MARK: - Note Errors

enum NoteError: LocalizedError {
    case noteNotFound
    case createFailed
    case updateFailed
    case deleteFailed
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noteNotFound:
            return "Note not found"
        case .createFailed:
            return "Failed to create note"
        case .updateFailed:
            return "Failed to update note"
        case .deleteFailed:
            return "Failed to delete note"
        case .encryptionFailed:
            return "Failed to encrypt note"
        case .decryptionFailed:
            return "Failed to decrypt note"
        }
    }
}

// MARK: - Mock Data

#if DEBUG
extension Note {
    static func mock(
        id: String = UUID().uuidString,
        title: String = "Mock Note",
        content: String = "This is a sample note content."
    ) -> Note {
        Note(
            id: id,
            title: title,
            content: content,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var mockWithContent: Note {
        Note(
            title: "Meeting Notes",
            content: """
            ## Discussion Points
            
            1. Project timeline review
            2. Budget allocation
            3. Team assignments
            
            ### Action Items
            - Follow up with design team
            - Schedule next sync
            """,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension NoteSummary {
    static func mock(
        id: String = UUID().uuidString,
        title: String = "Mock Note",
        daysAgo: Int = 0
    ) -> NoteSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return NoteSummary(
            id: id,
            title: title,
            folderId: nil,
            pinned: false,
            archived: false,
            createdAt: date,
            updatedAt: date
        )
    }
}
#endif
