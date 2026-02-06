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
    #if os(iOS)
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    #elseif os(macOS)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    #endif
    
    // MARK: - Text Colors
    
    /// Primary text color
    static let textPrimary = Color.primary
    
    /// Secondary/muted text
    static let textSecondary = Color.secondary
    
    /// Tertiary/hint text
    #if os(iOS)
    static let textTertiary = Color(.tertiaryLabel)
    #elseif os(macOS)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    #endif
    
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
    #if os(iOS)
    static let divider = Color(.separator)
    static let border = Color(.separator)
    static let placeholder = Color(.placeholderText)
    #elseif os(macOS)
    static let divider = Color(nsColor: .separatorColor)
    static let border = Color(nsColor: .separatorColor)
    static let placeholder = Color(nsColor: .placeholderTextColor)
    #endif
    
    // MARK: - Gray Scale
    
    /// System gray colors for various UI elements
    enum Gray {
        #if os(iOS)
        static let gray = Color(.systemGray)
        static let gray2 = Color(.systemGray2)
        static let gray3 = Color(.systemGray3)
        static let gray4 = Color(.systemGray4)
        static let gray5 = Color(.systemGray5)
        static let gray6 = Color(.systemGray6)
        #elseif os(macOS)
        static let gray = Color(nsColor: .systemGray)
        static let gray2 = Color(nsColor: .systemGray).opacity(0.85)
        static let gray3 = Color(nsColor: .systemGray).opacity(0.7)
        static let gray4 = Color(nsColor: .systemGray).opacity(0.55)
        static let gray5 = Color(nsColor: .systemGray).opacity(0.4)
        static let gray6 = Color(nsColor: .systemGray).opacity(0.25)
        #endif
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
