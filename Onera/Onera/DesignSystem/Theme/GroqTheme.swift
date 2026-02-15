//
//  GroqTheme.swift
//  Onera
//
//  Groq-inspired theme: bold orange accent (#F55036), speed-focused aesthetic
//

import SwiftUI

// MARK: - Groq Light

struct GroqLightThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { .white }
    var secondaryBackground: Color { Color(red: 0.965, green: 0.965, blue: 0.969) } // #F7F7F8
    var tertiaryBackground: Color { Color(red: 0.937, green: 0.937, blue: 0.941) } // #EFEFF0
    
    // Text
    var textPrimary: Color { Color(red: 0.118, green: 0.118, blue: 0.130) } // #1E1E21
    var textSecondary: Color { Color(red: 0.400, green: 0.400, blue: 0.416) } // #66666A
    var textTertiary: Color { Color(red: 0.580, green: 0.580, blue: 0.596) } // #949498
    
    // Interactive
    var accent: Color { Color(red: 0.961, green: 0.314, blue: 0.212) } // #F55036
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { Color(red: 0.965, green: 0.965, blue: 0.969) }
    var assistantBubble: Color { .white }
    
    // Semantic
    var success: Color { Color(red: 0.220, green: 0.694, blue: 0.392) }
    var warning: Color { Color(red: 0.918, green: 0.616, blue: 0.188) }
    var error: Color { accent }
    var info: Color { Color(red: 0.259, green: 0.522, blue: 0.957) }
    
    // Surface
    var border: Color { Color(red: 0.878, green: 0.878, blue: 0.886) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.961, green: 0.482, blue: 0.384) } // Lighter orange
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.992, green: 0.910, blue: 0.898), // Light orange
                Color(red: 0.988, green: 0.953, blue: 0.949),
                .white,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.100, green: 0.100, blue: 0.100) }
    var onboardingPill: Color { Color(white: 0.18) }
    var onboardingSelected: Color { Color(white: 0.22) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { textPrimary }
    var onboardingTextSecondary: Color { textPrimary.opacity(0.65) }
    var onboardingTextTertiary: Color { textPrimary.opacity(0.4) }
}

// MARK: - Groq Dark

struct GroqDarkThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { Color(red: 0.102, green: 0.102, blue: 0.102) } // #1A1A1A
    var secondaryBackground: Color { Color(red: 0.149, green: 0.149, blue: 0.149) } // #262626
    var tertiaryBackground: Color { Color(red: 0.200, green: 0.200, blue: 0.200) } // #333333
    
    // Text
    var textPrimary: Color { Color(red: 0.941, green: 0.941, blue: 0.941) } // #F0F0F0
    var textSecondary: Color { Color(red: 0.659, green: 0.659, blue: 0.671) } // #A8A8AB
    var textTertiary: Color { Color(red: 0.478, green: 0.478, blue: 0.490) } // #7A7A7D
    
    // Interactive
    var accent: Color { Color(red: 0.961, green: 0.314, blue: 0.212) } // #F55036
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { secondaryBackground }
    var assistantBubble: Color { background }
    
    // Semantic
    var success: Color { Color(red: 0.302, green: 0.773, blue: 0.475) }
    var warning: Color { Color(red: 0.965, green: 0.706, blue: 0.318) }
    var error: Color { accent }
    var info: Color { Color(red: 0.541, green: 0.706, blue: 0.973) }
    
    // Surface
    var border: Color { Color.white.opacity(0.1) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.980, green: 0.533, blue: 0.435) }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.200, green: 0.090, blue: 0.065),
                Color(red: 0.145, green: 0.100, blue: 0.090),
                Color(red: 0.102, green: 0.102, blue: 0.102),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { .black }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(white: 0.22) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { .white }
    var onboardingTextSecondary: Color { .white.opacity(0.7) }
    var onboardingTextTertiary: Color { .white.opacity(0.45) }
}

// MARK: - Groq Theme Wrapper

struct GroqThemeColors: ThemeColors {
    let colorScheme: ColorScheme
    
    private var colors: ThemeColors {
        colorScheme == .dark ? GroqDarkThemeColors() : GroqLightThemeColors()
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
