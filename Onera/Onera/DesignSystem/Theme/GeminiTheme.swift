//
//  GeminiTheme.swift
//  Onera
//
//  Google Gemini-inspired theme: cool blue accent (#4285F4 light, #8AB4F8 dark)
//

import SwiftUI

// MARK: - Gemini Light

struct GeminiLightThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { .white }
    var secondaryBackground: Color { Color(red: 0.941, green: 0.957, blue: 0.976) } // #F0F4F9
    var tertiaryBackground: Color { Color(red: 0.918, green: 0.933, blue: 0.957) } // #EAEEF4
    
    // Text
    var textPrimary: Color { Color(red: 0.188, green: 0.196, blue: 0.220) } // #303238
    var textSecondary: Color { Color(red: 0.376, green: 0.392, blue: 0.427) } // #60646D
    var textTertiary: Color { Color(red: 0.557, green: 0.573, blue: 0.600) } // #8E9299
    
    // Interactive
    var accent: Color { Color(red: 0.259, green: 0.522, blue: 0.957) } // #4285F4
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { Color(red: 0.918, green: 0.933, blue: 0.957) }
    var assistantBubble: Color { .white }
    
    // Semantic
    var success: Color { Color(red: 0.212, green: 0.651, blue: 0.447) } // #36A672
    var warning: Color { Color(red: 0.918, green: 0.682, blue: 0.192) } // #EAAE31
    var error: Color { Color(red: 0.847, green: 0.263, blue: 0.263) } // #D84343
    var info: Color { accent }
    
    // Surface
    var border: Color { Color(red: 0.855, green: 0.871, blue: 0.898) } // #DADEE5
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.412, green: 0.353, blue: 0.804) } // Gemini purple
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.878, green: 0.918, blue: 0.984), // Light blue
                Color(red: 0.929, green: 0.949, blue: 0.984),
                .white,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.118, green: 0.122, blue: 0.125) }
    var onboardingPill: Color { Color(white: 0.20) }
    var onboardingSelected: Color { Color(white: 0.24) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { textPrimary }
    var onboardingTextSecondary: Color { textPrimary.opacity(0.65) }
    var onboardingTextTertiary: Color { textPrimary.opacity(0.4) }
}

// MARK: - Gemini Dark

struct GeminiDarkThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { Color(red: 0.118, green: 0.122, blue: 0.125) } // #1E1F20
    var secondaryBackground: Color { Color(red: 0.157, green: 0.165, blue: 0.173) } // #282A2C
    var tertiaryBackground: Color { Color(red: 0.208, green: 0.216, blue: 0.224) } // #353739
    
    // Text
    var textPrimary: Color { Color(red: 0.929, green: 0.933, blue: 0.941) } // #EDEEEF
    var textSecondary: Color { Color(red: 0.659, green: 0.667, blue: 0.682) } // #A8AAAE
    var textTertiary: Color { Color(red: 0.490, green: 0.498, blue: 0.514) } // #7D7F83
    
    // Interactive — lighter blue for dark mode
    var accent: Color { Color(red: 0.541, green: 0.706, blue: 0.973) } // #8AB4F8
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { secondaryBackground }
    var assistantBubble: Color { background }
    
    // Semantic
    var success: Color { Color(red: 0.329, green: 0.769, blue: 0.557) }
    var warning: Color { Color(red: 0.965, green: 0.753, blue: 0.337) }
    var error: Color { Color(red: 0.918, green: 0.400, blue: 0.400) }
    var info: Color { accent }
    
    // Surface
    var border: Color { Color.white.opacity(0.1) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.533, green: 0.475, blue: 0.871) }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.098, green: 0.141, blue: 0.220),
                Color(red: 0.110, green: 0.125, blue: 0.165),
                Color(red: 0.118, green: 0.122, blue: 0.125),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.070, green: 0.073, blue: 0.075) }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(white: 0.24) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { .white }
    var onboardingTextSecondary: Color { .white.opacity(0.7) }
    var onboardingTextTertiary: Color { .white.opacity(0.45) }
}

// MARK: - Gemini Theme Wrapper

struct GeminiThemeColors: ThemeColors {
    let colorScheme: ColorScheme
    
    private var colors: ThemeColors {
        colorScheme == .dark ? GeminiDarkThemeColors() : GeminiLightThemeColors()
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
