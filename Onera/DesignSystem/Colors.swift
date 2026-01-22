//
//  Colors.swift
//  Onera
//
//  Centralized color palette and semantic colors
//

import SwiftUI

/// Onera Design System - Color Tokens
/// All colors used throughout the app should be referenced from here
enum OneraColors {
    
    // MARK: - Background Colors
    
    /// Primary background color (adapts to light/dark mode)
    static let background = Color(.systemBackground)
    
    /// Secondary background for cards, sections
    static let secondaryBackground = Color(.secondarySystemBackground)
    
    /// Tertiary background for nested elements
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    
    // MARK: - Text Colors
    
    /// Primary text color
    static let textPrimary = Color.primary
    
    /// Secondary/muted text
    static let textSecondary = Color.secondary
    
    /// Tertiary/hint text
    static let textTertiary = Color(.tertiaryLabel)
    
    // MARK: - Interactive Colors
    
    /// App accent color (defined in Assets)
    static let accent = Color.accentColor
    
    /// Tint color for interactive elements
    static let tint = Color.accentColor
    
    // MARK: - Semantic Colors
    
    /// Destructive actions (delete, remove, errors)
    static let destructive = Color.red
    
    /// Success states (completed, verified)
    static let success = Color.green
    
    /// Warning states (caution, pending)
    static let warning = Color.orange
    
    /// Informational states
    static let info = Color.blue
    
    // MARK: - Feature-Specific Colors
    
    /// AI reasoning/thinking indicator
    static let reasoning = Color.purple
    
    /// Recording indicator
    static let recording = Color.red
    
    /// Encryption status indicator
    static let encryption = Color.green
    
    // MARK: - Surface Colors
    
    /// Divider/separator color
    static let divider = Color(.separator)
    
    /// Border color for inputs and cards
    static let border = Color(.separator)
    
    /// Placeholder text color
    static let placeholder = Color(.placeholderText)
    
    // MARK: - Gray Scale
    
    /// System gray colors for various UI elements
    enum Gray {
        static let gray = Color(.systemGray)
        static let gray2 = Color(.systemGray2)
        static let gray3 = Color(.systemGray3)
        static let gray4 = Color(.systemGray4)
        static let gray5 = Color(.systemGray5)
        static let gray6 = Color(.systemGray6)
    }
    
    // MARK: - Overlay Colors
    
    /// Semi-transparent overlay for modals/sheets
    static let overlay = Color.black.opacity(0.3)
    
    /// Light overlay for hover states
    static let overlayLight = Color.black.opacity(0.08)
}

// MARK: - Color Extensions

extension Color {
    /// Convenience accessor for Onera colors
    static let onera = OneraColors.self
}
