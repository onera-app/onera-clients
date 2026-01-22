//
//  AppTheme.swift
//  Onera
//
//  Theme protocol and types for the design system
//

import SwiftUI

/// Available app themes
enum AppTheme: String, CaseIterable, Identifiable {
    case system   // Current Onera default (iOS system colors)
    case claude   // Claude-inspired warm, calm theme
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Default"
        case .claude: return "Claude"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "iOS system colors"
        case .claude: return "Warm, calm, academic"
        }
    }
}

/// Protocol defining all theme colors
/// Conforming types provide colors for both light and dark mode
protocol ThemeColors {
    
    // MARK: - Background Colors
    
    /// Primary background color
    var background: Color { get }
    
    /// Secondary background for cards, sections
    var secondaryBackground: Color { get }
    
    /// Tertiary background for nested elements
    var tertiaryBackground: Color { get }
    
    // MARK: - Text Colors
    
    /// Primary text color
    var textPrimary: Color { get }
    
    /// Secondary/muted text
    var textSecondary: Color { get }
    
    /// Tertiary/hint text
    var textTertiary: Color { get }
    
    // MARK: - Interactive Colors
    
    /// Primary accent color for links, active states
    var accent: Color { get }
    
    /// Tint color for interactive elements
    var tint: Color { get }
    
    // MARK: - Chat Colors
    
    /// User message bubble background
    var userBubble: Color { get }
    
    /// Assistant message bubble/area background
    var assistantBubble: Color { get }
    
    // MARK: - Semantic Colors
    
    /// Success states (completed, verified)
    var success: Color { get }
    
    /// Warning states (caution, pending)
    var warning: Color { get }
    
    /// Error/destructive states
    var error: Color { get }
    
    /// Informational states
    var info: Color { get }
    
    // MARK: - Surface Colors
    
    /// Border/divider color
    var border: Color { get }
    
    /// Placeholder text color
    var placeholder: Color { get }
    
    // MARK: - Special Colors
    
    /// AI reasoning/thinking indicator
    var reasoning: Color { get }
}

// MARK: - Default Theme (iOS System Colors)

/// Default theme using iOS system colors
/// Adapts automatically to light/dark mode via system semantics
struct DefaultThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { Color(.systemBackground) }
    var secondaryBackground: Color { Color(.secondarySystemBackground) }
    var tertiaryBackground: Color { Color(.tertiarySystemBackground) }
    
    // Text
    var textPrimary: Color { Color.primary }
    var textSecondary: Color { Color.secondary }
    var textTertiary: Color { Color(.tertiaryLabel) }
    
    // Interactive
    var accent: Color { Color.accentColor }
    var tint: Color { Color.accentColor }
    
    // Chat
    var userBubble: Color { Color(.systemGray5) }
    var assistantBubble: Color { Color(.systemBackground) }
    
    // Semantic
    var success: Color { Color.green }
    var warning: Color { Color.orange }
    var error: Color { Color.red }
    var info: Color { Color.blue }
    
    // Surface
    var border: Color { Color(.separator) }
    var placeholder: Color { Color(.placeholderText) }
    
    // Special
    var reasoning: Color { Color.purple }
}
