//
//  ThemeManager.swift
//  Onera
//
//  Observable manager for app theme state
//

import SwiftUI

/// Manages the current app theme and persists user preference
@Observable
final class ThemeManager {
    
    /// Shared singleton instance
    static let shared = ThemeManager()
    
    /// Storage key for persisting theme preference
    private static let storageKey = "appTheme"
    
    /// Currently selected theme
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.storageKey)
        }
    }
    
    private init() {
        // Load saved theme or default to system
        if let savedTheme = UserDefaults.standard.string(forKey: Self.storageKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }
    }
    
    /// Get theme colors for the current theme and color scheme
    /// - Parameter colorScheme: The current system color scheme (light/dark)
    /// - Returns: ThemeColors instance with appropriate colors
    func colors(for colorScheme: ColorScheme) -> ThemeColors {
        switch currentTheme {
        case .system:
            return DefaultThemeColors()
        case .claude:
            return ClaudeThemeColors(colorScheme: colorScheme)
        }
    }
    
    /// Check if Claude theme is active
    var isClaudeTheme: Bool {
        currentTheme == .claude
    }
    
    /// Toggle between themes
    func toggleTheme() {
        currentTheme = currentTheme == .system ? .claude : .system
    }
}

// MARK: - Convenience Extensions

extension ThemeManager {
    /// Get all available themes for UI selection
    var availableThemes: [AppTheme] {
        AppTheme.allCases
    }
}
