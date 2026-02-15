//
//  T3ChatTheme.swift
//  Onera
//
//  T3 Chat-inspired theme: dark, modern, developer-focused, purple accent (#A855F7)
//

import SwiftUI

// MARK: - T3 Chat Light

struct T3ChatLightThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { Color(red: 0.961, green: 0.961, blue: 0.961) } // #F5F5F5
    var secondaryBackground: Color { .white }
    var tertiaryBackground: Color { Color(red: 0.941, green: 0.941, blue: 0.953) } // #F0F0F3
    
    // Text
    var textPrimary: Color { Color(red: 0.094, green: 0.094, blue: 0.094) } // #181818
    var textSecondary: Color { Color(red: 0.400, green: 0.400, blue: 0.420) } // #66666B
    var textTertiary: Color { Color(red: 0.580, green: 0.580, blue: 0.600) } // #949499
    
    // Interactive
    var accent: Color { Color(red: 0.659, green: 0.333, blue: 0.969) } // #A855F7
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { Color(red: 0.941, green: 0.941, blue: 0.953) }
    var assistantBubble: Color { .white }
    
    // Semantic
    var success: Color { Color(red: 0.220, green: 0.694, blue: 0.392) }
    var warning: Color { Color(red: 0.918, green: 0.616, blue: 0.188) }
    var error: Color { Color(red: 0.863, green: 0.286, blue: 0.286) }
    var info: Color { accent }
    
    // Surface
    var border: Color { Color(red: 0.878, green: 0.878, blue: 0.886) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { accent }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.929, green: 0.890, blue: 0.988), // Light purple
                Color(red: 0.957, green: 0.937, blue: 0.988),
                Color(red: 0.961, green: 0.961, blue: 0.961),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.059, green: 0.059, blue: 0.059) }
    var onboardingPill: Color { Color(white: 0.16) }
    var onboardingSelected: Color { Color(white: 0.20) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { textPrimary }
    var onboardingTextSecondary: Color { textPrimary.opacity(0.65) }
    var onboardingTextTertiary: Color { textPrimary.opacity(0.4) }
}

// MARK: - T3 Chat Dark

struct T3ChatDarkThemeColors: ThemeColors {
    
    // Backgrounds — near-black, developer aesthetic
    var background: Color { Color(red: 0.039, green: 0.039, blue: 0.039) } // #0A0A0A
    var secondaryBackground: Color { Color(red: 0.090, green: 0.090, blue: 0.090) } // #171717
    var tertiaryBackground: Color { Color(red: 0.141, green: 0.141, blue: 0.141) } // #242424
    
    // Text
    var textPrimary: Color { Color(red: 0.933, green: 0.933, blue: 0.933) } // #EEEEEE
    var textSecondary: Color { Color(red: 0.639, green: 0.639, blue: 0.659) } // #A3A3A8
    var textTertiary: Color { Color(red: 0.459, green: 0.459, blue: 0.478) } // #75757A
    
    // Interactive
    var accent: Color { Color(red: 0.659, green: 0.333, blue: 0.969) } // #A855F7
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { secondaryBackground }
    var assistantBubble: Color { background }
    
    // Semantic
    var success: Color { Color(red: 0.302, green: 0.773, blue: 0.475) }
    var warning: Color { Color(red: 0.965, green: 0.706, blue: 0.318) }
    var error: Color { Color(red: 0.929, green: 0.400, blue: 0.400) }
    var info: Color { accent }
    
    // Surface
    var border: Color { Color.white.opacity(0.08) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { accent }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.110, green: 0.059, blue: 0.165),
                Color(red: 0.065, green: 0.050, blue: 0.090),
                Color(red: 0.039, green: 0.039, blue: 0.039),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { .black }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(white: 0.18) }
    var goldAccent: Color { accent }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { .white }
    var onboardingTextSecondary: Color { .white.opacity(0.7) }
    var onboardingTextTertiary: Color { .white.opacity(0.45) }
}

// MARK: - T3 Chat Theme Wrapper

struct T3ChatThemeColors: ThemeColors {
    let colorScheme: ColorScheme
    
    private var colors: ThemeColors {
        colorScheme == .dark ? T3ChatDarkThemeColors() : T3ChatLightThemeColors()
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
