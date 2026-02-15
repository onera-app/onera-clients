//
//  ChatGPTTheme.swift
//  Onera
//
//  ChatGPT-inspired theme: clean, minimal, teal accent (#10A37F)
//

import SwiftUI

// MARK: - ChatGPT Light

struct ChatGPTLightThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { .white }
    var secondaryBackground: Color { Color(red: 0.969, green: 0.969, blue: 0.973) } // #F7F7F8
    var tertiaryBackground: Color { Color(red: 0.937, green: 0.937, blue: 0.945) } // #EFEFF1
    
    // Text
    var textPrimary: Color { Color(red: 0.208, green: 0.212, blue: 0.224) } // #353638
    var textSecondary: Color { Color(red: 0.424, green: 0.424, blue: 0.443) } // #6C6C71
    var textTertiary: Color { Color(red: 0.604, green: 0.604, blue: 0.620) } // #9A9A9E
    
    // Interactive
    var accent: Color { Color(red: 0.063, green: 0.639, blue: 0.498) } // #10A37F
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { Color(red: 0.969, green: 0.969, blue: 0.973) }
    var assistantBubble: Color { .white }
    
    // Semantic
    var success: Color { Color(red: 0.063, green: 0.639, blue: 0.498) } // Teal
    var warning: Color { Color(red: 0.902, green: 0.600, blue: 0.153) }
    var error: Color { Color(red: 0.863, green: 0.286, blue: 0.286) }
    var info: Color { accent }
    
    // Surface
    var border: Color { Color(red: 0.878, green: 0.878, blue: 0.886) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.063, green: 0.639, blue: 0.498).opacity(0.8) }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.882, green: 0.969, blue: 0.949), // Light teal
                Color(red: 0.949, green: 0.973, blue: 0.969),
                .white,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.129, green: 0.129, blue: 0.129) }
    var onboardingPill: Color { Color(white: 0.20) }
    var onboardingSelected: Color { Color(white: 0.24) }
    var goldAccent: Color { Color(red: 0.902, green: 0.600, blue: 0.153) }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { Color(red: 0.208, green: 0.212, blue: 0.224) }
    var onboardingTextSecondary: Color { Color(red: 0.208, green: 0.212, blue: 0.224).opacity(0.65) }
    var onboardingTextTertiary: Color { Color(red: 0.208, green: 0.212, blue: 0.224).opacity(0.4) }
}

// MARK: - ChatGPT Dark

struct ChatGPTDarkThemeColors: ThemeColors {
    
    // Backgrounds
    var background: Color { Color(red: 0.130, green: 0.130, blue: 0.130) } // #212121
    var secondaryBackground: Color { Color(red: 0.184, green: 0.184, blue: 0.184) } // #2F2F2F
    var tertiaryBackground: Color { Color(red: 0.224, green: 0.224, blue: 0.224) } // #393939
    
    // Text
    var textPrimary: Color { Color(red: 0.929, green: 0.929, blue: 0.933) } // #EDEDED
    var textSecondary: Color { Color(red: 0.682, green: 0.682, blue: 0.694) } // #AEAEB1
    var textTertiary: Color { Color(red: 0.502, green: 0.502, blue: 0.514) } // #808083
    
    // Interactive
    var accent: Color { Color(red: 0.063, green: 0.639, blue: 0.498) } // #10A37F
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { secondaryBackground }
    var assistantBubble: Color { background }
    
    // Semantic
    var success: Color { Color(red: 0.200, green: 0.733, blue: 0.584) }
    var warning: Color { Color(red: 0.949, green: 0.686, blue: 0.306) }
    var error: Color { Color(red: 0.918, green: 0.420, blue: 0.420) }
    var info: Color { accent }
    
    // Surface
    var border: Color { Color.white.opacity(0.1) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { accent }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.063, green: 0.180, blue: 0.153),
                Color(red: 0.100, green: 0.130, blue: 0.125),
                Color(red: 0.130, green: 0.130, blue: 0.130),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.080, green: 0.080, blue: 0.080) }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(white: 0.26) }
    var goldAccent: Color { Color(red: 0.949, green: 0.686, blue: 0.306) }
    var ctaButton: Color { accent }
    var onboardingTextPrimary: Color { .white }
    var onboardingTextSecondary: Color { .white.opacity(0.7) }
    var onboardingTextTertiary: Color { .white.opacity(0.45) }
}

// MARK: - ChatGPT Theme Wrapper

struct ChatGPTThemeColors: ThemeColors {
    let colorScheme: ColorScheme
    
    private var colors: ThemeColors {
        colorScheme == .dark ? ChatGPTDarkThemeColors() : ChatGPTLightThemeColors()
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
