//
//  ClaudeTheme.swift
//  Onera
//
//  Claude/Anthropic "Editorial Tech" design system
//  Warm organic tones, coral accent, newsprint backgrounds
//  Uses serif fonts for AI voice, sans-serif for UI
//

import SwiftUI

// MARK: - Claude Theme Colors

/// Claude theme for light mode
/// "Newsprint" cream backgrounds, warm charcoal text, coral accent
struct ClaudeLightThemeColors: ThemeColors {
    
    // MARK: - Backgrounds
    
    /// Newsprint/Cream white - not sterile #FFFFFF
    var background: Color {
        Color(red: 0.984, green: 0.976, blue: 0.965) // #FBF9F6
    }
    
    /// Slightly darker for cards/elevated surfaces
    var secondaryBackground: Color {
        Color(red: 0.965, green: 0.957, blue: 0.945) // #F6F4F1
    }
    
    /// Tertiary for nested elements/hover states
    var tertiaryBackground: Color {
        Color(red: 0.945, green: 0.937, blue: 0.922) // #F1EFEB
    }
    
    // MARK: - Text
    
    /// Warm charcoal - almost black
    var textPrimary: Color {
        Color(red: 0.098, green: 0.094, blue: 0.090) // #191817
    }
    
    /// Warm gray for secondary text
    var textSecondary: Color {
        Color(red: 0.459, green: 0.447, blue: 0.435) // #75726F
    }
    
    /// Muted for hints/placeholders
    var textTertiary: Color {
        Color(red: 0.620, green: 0.608, blue: 0.596) // #9E9B98
    }
    
    // MARK: - Interactive
    
    /// Claude Coral - the primary brand accent
    var accent: Color {
        Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757
    }
    
    var tint: Color { accent }
    
    // MARK: - Chat Bubbles
    
    /// User message bubble - subtle warm tone
    var userBubble: Color {
        Color(red: 0.953, green: 0.902, blue: 0.886) // #F3E6E2 - Pale coral tint
    }
    
    /// Assistant area - clean background
    var assistantBubble: Color {
        background
    }
    
    // MARK: - Semantic
    
    /// Success green
    var success: Color {
        Color(red: 0.235, green: 0.557, blue: 0.235) // #3C8E3C
    }
    
    /// Warning amber - warm tone
    var warning: Color {
        Color(red: 0.820, green: 0.557, blue: 0.196) // #D18E32
    }
    
    /// Error - muted red
    var error: Color {
        Color(red: 0.761, green: 0.290, blue: 0.290) // #C24A4A
    }
    
    /// Info - using accent coral
    var info: Color { accent }
    
    // MARK: - Surface
    
    /// Subtle border
    var border: Color {
        Color(red: 0.878, green: 0.867, blue: 0.855) // #E0DDDA
    }
    
    var placeholder: Color { textTertiary }
    
    // MARK: - Special
    
    /// Reasoning indicator - coral accent
    var reasoning: Color { accent }
    
    // MARK: - Onboarding
    
    /// Claude light onboarding uses warm cream-to-coral gradient
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.984, green: 0.976, blue: 0.965),  // Cream
                Color(red: 0.965, green: 0.929, blue: 0.914),  // Warm blush
                Color(red: 0.953, green: 0.902, blue: 0.886),  // Pale coral
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.098, green: 0.094, blue: 0.090) }
    var onboardingPill: Color { Color(red: 0.184, green: 0.180, blue: 0.176) }
    var onboardingSelected: Color { Color(red: 0.220, green: 0.216, blue: 0.212) }
    var goldAccent: Color { Color(red: 0.820, green: 0.557, blue: 0.196) }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { Color(red: 0.098, green: 0.094, blue: 0.090) }
    var onboardingTextSecondary: Color { Color(red: 0.098, green: 0.094, blue: 0.090).opacity(0.65) }
    var onboardingTextTertiary: Color { Color(red: 0.098, green: 0.094, blue: 0.090).opacity(0.4) }
}

/// Claude theme for dark mode
/// Warm charcoal backgrounds (not pure black), coral accent
struct ClaudeDarkThemeColors: ThemeColors {
    
    // MARK: - Backgrounds
    
    /// Warm charcoal - NOT pure black
    var background: Color {
        Color(red: 0.098, green: 0.094, blue: 0.090) // #191817
    }
    
    /// Elevated surface/cards
    var secondaryBackground: Color {
        Color(red: 0.145, green: 0.141, blue: 0.137) // #252423
    }
    
    /// Tertiary/hover states
    var tertiaryBackground: Color {
        Color(red: 0.184, green: 0.180, blue: 0.176) // #2F2E2D
    }
    
    // MARK: - Text
    
    /// White text
    var textPrimary: Color {
        Color.white // #FFFFFF
    }
    
    /// Muted warm gray
    var textSecondary: Color {
        Color(red: 0.620, green: 0.620, blue: 0.620) // #9E9E9E
    }
    
    /// Placeholder/hint text
    var textTertiary: Color {
        Color(red: 0.400, green: 0.400, blue: 0.400) // #666666
    }
    
    // MARK: - Interactive
    
    /// Claude Coral - same as light mode for brand consistency
    var accent: Color {
        Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757
    }
    
    var tint: Color { accent }
    
    // MARK: - Chat Bubbles
    
    /// User message bubble - elevated surface
    var userBubble: Color {
        secondaryBackground
    }
    
    /// Assistant area - main background
    var assistantBubble: Color {
        background
    }
    
    // MARK: - Semantic
    
    /// Success green - brighter for dark mode
    var success: Color {
        Color(red: 0.357, green: 0.714, blue: 0.357) // #5BB65B
    }
    
    /// Warning amber - brighter
    var warning: Color {
        Color(red: 0.918, green: 0.686, blue: 0.333) // #EAAF55
    }
    
    /// Error red - brighter for visibility
    var error: Color {
        Color(red: 0.890, green: 0.420, blue: 0.420) // #E36B6B
    }
    
    /// Info - coral accent
    var info: Color { accent }
    
    // MARK: - Surface
    
    /// Subtle border - white with low opacity
    var border: Color {
        Color.white.opacity(0.1) // rgba(255,255,255,0.1)
    }
    
    var placeholder: Color { textTertiary }
    
    // MARK: - Special
    
    /// Reasoning indicator - coral
    var reasoning: Color { accent }
    
    // MARK: - Onboarding
    
    /// Claude dark onboarding uses warm charcoal-to-deep gradient
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.145, green: 0.141, blue: 0.137),
                Color(red: 0.120, green: 0.110, blue: 0.105),
                Color(red: 0.098, green: 0.094, blue: 0.090),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.065, green: 0.063, blue: 0.060) }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(red: 0.220, green: 0.216, blue: 0.212) }
    var goldAccent: Color { Color(red: 0.918, green: 0.686, blue: 0.333) }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { .white }
    var onboardingTextSecondary: Color { .white.opacity(0.7) }
    var onboardingTextTertiary: Color { .white.opacity(0.45) }
}

// MARK: - Claude Theme Wrapper

/// Wrapper that returns appropriate Claude colors based on color scheme
struct ClaudeThemeColors: ThemeColors {
    let colorScheme: ColorScheme
    
    private var colors: ThemeColors {
        colorScheme == .dark ? ClaudeDarkThemeColors() : ClaudeLightThemeColors()
    }
    
    var background: Color { colors.background }
    var secondaryBackground: Color { colors.secondaryBackground }
    var tertiaryBackground: Color { colors.tertiaryBackground }
    var textPrimary: Color { colors.textPrimary }
    var textSecondary: Color { colors.textSecondary }
    var textTertiary: Color { colors.textTertiary }
    var accent: Color { colors.accent }
    var tint: Color { colors.tint }
    var userBubble: Color { colors.userBubble }
    var assistantBubble: Color { colors.assistantBubble }
    var success: Color { colors.success }
    var warning: Color { colors.warning }
    var error: Color { colors.error }
    var info: Color { colors.info }
    var border: Color { colors.border }
    var placeholder: Color { colors.placeholder }
    var reasoning: Color { colors.reasoning }
    var onboardingGradient: LinearGradient { colors.onboardingGradient }
    var onboardingSheetBackground: Color { colors.onboardingSheetBackground }
    var onboardingPill: Color { colors.onboardingPill }
    var onboardingSelected: Color { colors.onboardingSelected }
    var goldAccent: Color { colors.goldAccent }
    var ctaButton: Color { colors.ctaButton }
    var onboardingTextPrimary: Color { colors.onboardingTextPrimary }
    var onboardingTextSecondary: Color { colors.onboardingTextSecondary }
    var onboardingTextTertiary: Color { colors.onboardingTextTertiary }
}

// MARK: - Claude Design Constants

/// Claude-specific design values beyond colors
enum ClaudeDesign {
    /// Border radius values matching Claude's design
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 999 // Fully rounded for buttons/inputs
    }
    
    /// Shadow for floating elements (FAB, cards)
    static let floatingShadow = Shadow(
        color: .black.opacity(0.3),
        radius: 12,
        x: 0,
        y: 4
    )
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}
