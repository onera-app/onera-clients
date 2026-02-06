//
//  Prompt.swift
//  Onera
//
//  Prompt domain models for custom prompt templates
//

import Foundation

// MARK: - Prompt

struct Prompt: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var description: String?
    var content: String
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        name: String = "Untitled Prompt",
        description: String? = nil,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var previewText: String {
        if content.isEmpty {
            return "No content"
        }
        return content.truncatedAtWord(to: 100)
    }
    
    /// Extracts variable placeholders from the content (e.g., {{variable}})
    var variables: [String] {
        let pattern = "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }
    
    /// Fills in variables with provided values
    func filled(with values: [String: String]) -> String {
        var result = content
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
            result = result.replacingOccurrences(of: "{{ \(key) }}", with: value)
        }
        return result
    }
}

// MARK: - Prompt Summary (for list display)

struct PromptSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date
    
    var group: PromptGroup {
        PromptGroup.for(date: updatedAt)
    }
}

// MARK: - Prompt Group (for list grouping)

enum PromptGroup: Hashable, Comparable, Sendable {
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
    
    static func < (lhs: PromptGroup, rhs: PromptGroup) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
    
    static func `for`(date: Date) -> PromptGroup {
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

// MARK: - Prompt Errors

enum PromptError: LocalizedError {
    case promptNotFound
    case createFailed
    case updateFailed
    case deleteFailed
    case encryptionFailed
    case decryptionFailed
    case invalidContent
    
    var errorDescription: String? {
        switch self {
        case .promptNotFound:
            return "Prompt not found"
        case .createFailed:
            return "Failed to create prompt"
        case .updateFailed:
            return "Failed to update prompt"
        case .deleteFailed:
            return "Failed to delete prompt"
        case .encryptionFailed:
            return "Failed to encrypt prompt"
        case .decryptionFailed:
            return "Failed to decrypt prompt"
        case .invalidContent:
            return "Prompt content is invalid"
        }
    }
}

// MARK: - Mock Data

#if DEBUG
extension Prompt {
    static func mock(
        id: String = UUID().uuidString,
        name: String = "Mock Prompt",
        description: String? = "A sample prompt for testing",
        content: String = "Please help me with {{task}}."
    ) -> Prompt {
        Prompt(
            id: id,
            name: name,
            description: description,
            content: content,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var codeReviewPrompt: Prompt {
        Prompt(
            name: "Code Review Helper",
            description: "Helps review code for best practices",
            content: """
            Please review the following {{language}} code for:
            
            1. Best practices and conventions
            2. Potential bugs or issues
            3. Performance improvements
            4. Security concerns
            
            Code:
            ```{{language}}
            {{code}}
            ```
            
            Provide specific, actionable feedback.
            """,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var explainCodePrompt: Prompt {
        Prompt(
            name: "Explain Code",
            description: "Get detailed explanations of code",
            content: """
            Please explain this code in detail:
            
            ```{{language}}
            {{code}}
            ```
            
            Include:
            - What it does
            - How it works step by step
            - Any important concepts used
            """,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        )
    }
}

extension PromptSummary {
    static func mock(
        id: String = UUID().uuidString,
        name: String = "Mock Prompt",
        description: String? = "A sample prompt",
        daysAgo: Int = 0
    ) -> PromptSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return PromptSummary(
            id: id,
            name: name,
            description: description,
            createdAt: date,
            updatedAt: date
        )
    }
}
#endif
