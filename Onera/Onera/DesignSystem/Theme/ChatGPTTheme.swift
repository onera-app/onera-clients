//
//  ChatGPTTheme.swift
//  Onera
//
//  ChatGPT-inspired theme: clean, minimal, teal accent (#10A37F)
//

import SwiftUI

// MARK: - ChatGPT Light

struct ChatGPTLightThemeColors: ThemeColors {
    
    // Backgrounds — ChatGPT light: clean white with warm off-white sidebar
    var background: Color { Color(red: 0.953, green: 0.953, blue: 0.953) } // #F3F3F3 sidebar
    var secondaryBackground: Color { .white }                               // #FFFFFF content
    var tertiaryBackground: Color { Color(red: 0.961, green: 0.961, blue: 0.965) } // #F5F5F7 input surface
    
    // Text
    var textPrimary: Color { Color(red: 0.129, green: 0.129, blue: 0.141) } // #212124 near-black
    var textSecondary: Color { Color(red: 0.424, green: 0.424, blue: 0.443) } // #6C6C71
    var textTertiary: Color { Color(red: 0.604, green: 0.604, blue: 0.620) } // #9A9A9E
    
    // Interactive
    var accent: Color { Color(red: 0.129, green: 0.129, blue: 0.141) } // Near-black in light mode (ChatGPT style)
    var tint: Color { accent }
    
    // Chat
    var userBubble: Color { tertiaryBackground }
    var assistantBubble: Color { .white }
    
    // Semantic
    var success: Color { Color(red: 0.063, green: 0.639, blue: 0.498) }
    var warning: Color { Color(red: 0.902, green: 0.600, blue: 0.153) }
    var error: Color { Color(red: 0.863, green: 0.286, blue: 0.286) }
    var info: Color { Color(red: 0.063, green: 0.639, blue: 0.498) }
    
    // Surface
    var border: Color { Color.black.opacity(0.08) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.063, green: 0.639, blue: 0.498).opacity(0.8) }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.882, green: 0.969, blue: 0.949),
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
    var onboardingTextPrimary: Color { textPrimary }
    var onboardingTextSecondary: Color { textPrimary.opacity(0.65) }
    var onboardingTextTertiary: Color { textPrimary.opacity(0.4) }
}

// MARK: - ChatGPT Dark

struct ChatGPTDarkThemeColors: ThemeColors {
    
    // Backgrounds — matched from ChatGPT macOS app (Dec 2025)
    var background: Color { Color(red: 0.090, green: 0.090, blue: 0.090) } // #171717 sidebar-level dark
    var secondaryBackground: Color { Color(red: 0.130, green: 0.130, blue: 0.130) } // #212121 content bg
    var tertiaryBackground: Color { Color(red: 0.184, green: 0.184, blue: 0.184) } // #2F2F2F input/card surface
    
    // Text
    var textPrimary: Color { Color(red: 0.925, green: 0.925, blue: 0.925) } // #ECECEC
    var textSecondary: Color { Color(red: 0.706, green: 0.706, blue: 0.706) } // #B4B4B4
    var textTertiary: Color { Color(red: 0.557, green: 0.557, blue: 0.557) } // #8E8E8E
    
    // Interactive — neutral white in dark mode (ChatGPT doesn't show teal in dark UI)
    var accent: Color { .white }
    var tint: Color { .white }
    
    // Chat
    var userBubble: Color { tertiaryBackground }
    var assistantBubble: Color { secondaryBackground }
    
    // Semantic
    var success: Color { Color(red: 0.200, green: 0.733, blue: 0.584) }
    var warning: Color { Color(red: 0.949, green: 0.686, blue: 0.306) }
    var error: Color { Color(red: 0.918, green: 0.420, blue: 0.420) }
    var info: Color { Color(red: 0.063, green: 0.639, blue: 0.498) }
    
    // Surface
    var border: Color { Color.white.opacity(0.08) }
    var placeholder: Color { textTertiary }
    
    // Special
    var reasoning: Color { Color(red: 0.063, green: 0.639, blue: 0.498) }
    
    // Onboarding
    var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.063, green: 0.140, blue: 0.120),
                Color(red: 0.090, green: 0.100, blue: 0.095),
                Color(red: 0.090, green: 0.090, blue: 0.090),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    var onboardingSheetBackground: Color { Color(red: 0.060, green: 0.060, blue: 0.060) }
    var onboardingPill: Color { tertiaryBackground }
    var onboardingSelected: Color { Color(white: 0.22) }
    var goldAccent: Color { Color(red: 0.949, green: 0.686, blue: 0.306) }
    var ctaButton: Color { .white }
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
    var surfaceElevated: Color { colors.surfaceElevated }
    var surfaceSunken: Color { colors.surfaceSunken }
    var textOnAccent: Color { colors.textOnAccent }
    var iconPrimary: Color { colors.iconPrimary }
    var iconSecondary: Color { colors.iconSecondary }
    var iconTertiary: Color { colors.iconTertiary }
}
