//
//  AppTheme.swift
//  Onera
//
//  Theme protocol and types for the design system
//

import SwiftUI

/// Available app themes
enum AppTheme: String, CaseIterable, Identifiable {
    case system    // Current Onera default (iOS system colors)
    case claude    // Claude-inspired warm, calm theme
    case chatgpt   // OpenAI ChatGPT-inspired clean teal
    case t3chat    // T3 Chat-inspired dark, modern purple
    case gemini    // Google Gemini-inspired cool blue
    case groq      // Groq-inspired bold orange
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Default"
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .t3chat: return "T3 Chat"
        case .gemini: return "Gemini"
        case .groq: return "Groq"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "iOS system colors"
        case .claude: return "Warm, calm, academic"
        case .chatgpt: return "Clean, minimal, teal accent"
        case .t3chat: return "Dark, modern, developer-focused"
        case .gemini: return "Cool blue, Google AI-inspired"
        case .groq: return "Bold orange, speed-focused"
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
    
    // MARK: - Onboarding Colors
    
    /// Welcome gradient for onboarding background
    var onboardingGradient: LinearGradient { get }
    
    /// Dark sheet / bottom card background for onboarding
    var onboardingSheetBackground: Color { get }
    
    /// Elevated surface in onboarding (pills, input fields)
    var onboardingPill: Color { get }
    
    /// Selected/highlighted row in onboarding drawer
    var onboardingSelected: Color { get }
    
    /// Gold accent (badges, premium indicators)
    var goldAccent: Color { get }
    
    /// CTA button colour for onboarding
    var ctaButton: Color { get }
    
    // MARK: - Onboarding Text Colors (on gradient)
    
    /// Primary text on onboarding gradient background
    var onboardingTextPrimary: Color { get }
    
    /// Secondary text on onboarding gradient background
    var onboardingTextSecondary: Color { get }
    
    /// Tertiary text on onboarding gradient background
    var onboardingTextTertiary: Color { get }
    
    // MARK: - Extended Surface Colors
    
    /// Elevated surface (floating panels, popovers)
    var surfaceElevated: Color { get }
    
    /// Sunken/recessed surface (code blocks, inset areas)
    var surfaceSunken: Color { get }
    
    /// Text rendered on accent-colored backgrounds
    var textOnAccent: Color { get }
    
    // MARK: - Icon Colors
    
    /// Primary icon color (matches textPrimary)
    var iconPrimary: Color { get }
    
    /// Secondary icon color (matches textSecondary)
    var iconSecondary: Color { get }
    
    /// Tertiary icon color (matches textTertiary)
    var iconTertiary: Color { get }
}

// MARK: - Default Implementations

extension ThemeColors {
    /// Default: elevated surface is slightly lighter than secondary background
    var surfaceElevated: Color { secondaryBackground }
    
    /// Default: sunken surface is tertiary background
    var surfaceSunken: Color { tertiaryBackground }
    
    /// Default: white text on accent backgrounds
    var textOnAccent: Color { .white }
    
    /// Default: icons follow text colors
    var iconPrimary: Color { textPrimary }
    var iconSecondary: Color { textSecondary }
    var iconTertiary: Color { textTertiary }
}

// MARK: - Default Theme (System Colors)

/// Default theme using system colors
/// Adapts automatically to light/dark mode via system semantics
struct DefaultThemeColors: ThemeColors {
    
    // Backgrounds
    #if os(iOS)
    var background: Color { Color(.systemBackground) }
    var secondaryBackground: Color { Color(.secondarySystemBackground) }
    var tertiaryBackground: Color { Color(.tertiarySystemBackground) }
    #elseif os(macOS)
    var background: Color { Color(nsColor: .windowBackgroundColor) }
    var secondaryBackground: Color { Color(nsColor: .controlBackgroundColor) }
    var tertiaryBackground: Color { Color(nsColor: .underPageBackgroundColor) }
    #endif
    
    // Text
    var textPrimary: Color { Color.primary }
    var textSecondary: Color { Color.secondary }
    #if os(iOS)
    var textTertiary: Color { Color(.tertiaryLabel) }
    #elseif os(macOS)
    var textTertiary: Color { Color(nsColor: .tertiaryLabelColor) }
    #endif
    
    // Interactive
    var accent: Color { Color.accentColor }
    var tint: Color { Color.accentColor }
    
    // Chat
    #if os(iOS)
    var userBubble: Color { Color(.systemGray5) }
    var assistantBubble: Color { Color(.systemBackground) }
    #elseif os(macOS)
    var userBubble: Color { Color(nsColor: .controlColor) }
    var assistantBubble: Color { Color(nsColor: .windowBackgroundColor) }
    #endif
    
    // Semantic
    var success: Color { Color.green }
    var warning: Color { Color.orange }
    var error: Color { Color.red }
    var info: Color { Color.blue }
    
    // Surface
    #if os(iOS)
    var border: Color { Color(.separator) }
    var placeholder: Color { Color(.placeholderText) }
    #elseif os(macOS)
    var border: Color { Color(nsColor: .separatorColor) }
    var placeholder: Color { Color(nsColor: .placeholderTextColor) }
    #endif
    
    // Special
    var reasoning: Color { Color.purple }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.85, blue: 0.96),
                Color(red: 0.76, green: 0.91, blue: 0.97),
                Color(red: 0.95, green: 0.88, blue: 0.84),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.09, green: 0.09, blue: 0.09) }
    var onboardingPill: Color { Color(white: 0.18) }
    var onboardingSelected: Color { Color(white: 0.22) }
    var goldAccent: Color { Color(red: 0.85, green: 0.68, blue: 0.30) }
    var ctaButton: Color { .blue }
    var onboardingTextPrimary: Color { .black }
    var onboardingTextSecondary: Color { .black.opacity(0.65) }
    var onboardingTextTertiary: Color { .black.opacity(0.4) }
}

// MARK: - OLED Dark Theme Wrapper

/// Wraps any ThemeColors and overrides backgrounds to pure black for OLED displays.
/// Only used when the user enables "OLED Black" in appearance settings while in dark mode.
struct OLEDDarkThemeColors: ThemeColors {
    private let base: ThemeColors
    
    init(wrapping base: ThemeColors) {
        self.base = base
    }
    
    // Override backgrounds to pure black / near-black
    var background: Color { .black }
    var secondaryBackground: Color { Color(white: 0.06) } // #0F0F0F
    var tertiaryBackground: Color { Color(white: 0.10) }  // #1A1A1A
    
    // Pass through everything else from the base theme
    var textPrimary: Color { base.textPrimary }
    var textSecondary: Color { base.textSecondary }
    var textTertiary: Color { base.textTertiary }
    var accent: Color { base.accent }
    var tint: Color { base.tint }
    var userBubble: Color { Color(white: 0.08) } // Slightly elevated on OLED
    var assistantBubble: Color { .black }
    var success: Color { base.success }
    var warning: Color { base.warning }
    var error: Color { base.error }
    var info: Color { base.info }
    var border: Color { base.border }
    var placeholder: Color { base.placeholder }
    var reasoning: Color { base.reasoning }
    
    // Onboarding - pass through from base, with OLED-appropriate overrides
    var onboardingGradient: LinearGradient { base.onboardingGradient }
    var onboardingSheetBackground: Color { .black }
    var onboardingPill: Color { Color(white: 0.10) }
    var onboardingSelected: Color { Color(white: 0.14) }
    var goldAccent: Color { base.goldAccent }
    var ctaButton: Color { base.ctaButton }
    var onboardingTextPrimary: Color { base.onboardingTextPrimary }
    var onboardingTextSecondary: Color { base.onboardingTextSecondary }
    var onboardingTextTertiary: Color { base.onboardingTextTertiary }
    
    // Extended surfaces — OLED-specific overrides
    var surfaceElevated: Color { Color(white: 0.08) }
    var surfaceSunken: Color { Color(white: 0.03) }
    var textOnAccent: Color { base.textOnAccent }
    var iconPrimary: Color { base.iconPrimary }
    var iconSecondary: Color { base.iconSecondary }
    var iconTertiary: Color { base.iconTertiary }
}
