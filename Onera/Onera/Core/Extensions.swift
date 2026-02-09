//
//  Extensions.swift
//  Onera
//
//  Common Swift extensions
//

import Foundation
import SwiftUI

// MARK: - Data Extensions

extension Data {
    
    /// Creates a hex string representation
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Creates Data from a hex string
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Securely zeros the data (for sensitive data cleanup)
    mutating func secureZero() {
        withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            memset_s(baseAddress, ptr.count, 0, ptr.count)
        }
    }
}

// MARK: - String Extensions

extension String {
    
    /// Validates email format
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// Truncates string to specified length with ellipsis
    func truncated(to length: Int, trailing: String = "…") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length)) + trailing
    }
    
    /// Truncates at word boundary
    func truncatedAtWord(to length: Int, trailing: String = "…") -> String {
        guard count > length else { return self }
        
        let truncated = String(prefix(length))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + trailing
        }
        return truncated + trailing
    }
}

// MARK: - Date Extensions

extension Date {
    
    /// Returns relative date string (Today, Yesterday, etc.)
    var relativeString: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                  self >= weekAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
    
    /// Time string (e.g., "3:45 PM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - View Extensions

extension View {
    
    /// Conditionally applies a transformation
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Hides the view based on condition
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden {
            self.hidden()
        } else {
            self
        }
    }
    
    #if os(iOS)
    /// Applies corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    #endif
}

// MARK: - Custom Shapes

#if os(iOS)
import UIKit

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

// MARK: - Result Extensions

extension Result {
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
    
    var value: Success? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    var error: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    
    /// Sleeps for specified seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// Sleeps for specified milliseconds
    static func sleep(milliseconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

// MARK: - Thinking Tag Parser

/// Parsed message content with thinking blocks extracted
struct ParsedMessageContent {
    let displayContent: String
    let thinkingContent: String?
    let isThinking: Bool
}

/// Shared utility for parsing thinking/reasoning blocks from LLM output
enum ThinkingTagParser {
    
    /// Supported thinking tags
    static let thinkingTags = ["think", "thinking", "reason", "reasoning"]
    
    /// Parse content and extract thinking blocks
    static func parse(_ content: String) -> ParsedMessageContent {
        guard !content.isEmpty else {
            return ParsedMessageContent(displayContent: "", thinkingContent: nil, isThinking: false)
        }
        
        var displayContent = content
        var thinkingBlocks: [String] = []
        var isThinking = false
        
        // Build regex pattern for complete blocks: <tag>content</tag>
        let tagsPattern = thinkingTags.joined(separator: "|")
        let completeBlockPattern = "<(\(tagsPattern))>([\\s\\S]*?)</\\1>"
        
        // Find and extract complete thinking blocks
        if let regex = try? NSRegularExpression(pattern: completeBlockPattern, options: [.caseInsensitive]) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
            
            // Process matches in reverse order to preserve indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let contentRange = match.range(at: 2)
                    let thinkingText = nsContent.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !thinkingText.isEmpty {
                        thinkingBlocks.insert(thinkingText, at: 0)
                    }
                    // Remove the block from display content
                    displayContent = (displayContent as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        
        // Check for incomplete (still streaming) thinking block: <tag>content (no closing tag)
        let openTagPattern = "<(\(tagsPattern))>([\\s\\S]*)$"
        if let regex = try? NSRegularExpression(pattern: openTagPattern, options: [.caseInsensitive]) {
            let nsDisplay = displayContent as NSString
            if let match = regex.firstMatch(in: displayContent, options: [], range: NSRange(location: 0, length: nsDisplay.length)) {
                if match.numberOfRanges >= 3 {
                    let contentRange = match.range(at: 2)
                    let thinkingText = nsDisplay.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !thinkingText.isEmpty {
                        thinkingBlocks.append(thinkingText)
                    }
                    // Remove the incomplete block from display content
                    displayContent = (displayContent as NSString).replacingCharacters(in: match.range, with: "")
                    isThinking = true
                }
            }
        }
        
        // Clean up display content
        displayContent = displayContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        let combinedThinking = thinkingBlocks.isEmpty ? nil : thinkingBlocks.joined(separator: "\n\n")
        
        return ParsedMessageContent(
            displayContent: displayContent,
            thinkingContent: combinedThinking,
            isThinking: isThinking
        )
    }
}

