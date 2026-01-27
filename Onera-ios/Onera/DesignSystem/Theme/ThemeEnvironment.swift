//
//  ThemeEnvironment.swift
//  Onera
//
//  SwiftUI environment integration for theme colors
//

import SwiftUI

// MARK: - Theme Environment Key

/// Environment key for accessing theme colors throughout the app
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeColors = DefaultThemeColors()
}

extension EnvironmentValues {
    /// Access the current theme colors
    var theme: ThemeColors {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme Manager Environment Key

/// Environment key for accessing the theme manager
private struct ThemeManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    /// Access the theme manager for changing themes
    var themeManager: ThemeManager {
        get { self[ThemeManagerEnvironmentKey.self] }
        set { self[ThemeManagerEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply theme colors from the theme manager based on current color scheme
    func themed() -> some View {
        modifier(ThemedViewModifier())
    }
}

/// View modifier that injects theme colors into the environment
private struct ThemedViewModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, ThemeManager.shared.colors(for: colorScheme))
    }
}

// MARK: - Preview Helpers

extension View {
    /// Preview with Claude theme in light mode
    func previewClaudeLight() -> some View {
        self
            .environment(\.theme, ClaudeLightThemeColors())
            .environment(\.colorScheme, .light)
    }
    
    /// Preview with Claude theme in dark mode
    func previewClaudeDark() -> some View {
        self
            .environment(\.theme, ClaudeDarkThemeColors())
            .environment(\.colorScheme, .dark)
    }
}
