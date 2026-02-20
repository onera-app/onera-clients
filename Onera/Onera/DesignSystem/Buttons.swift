//
//  Buttons.swift
//  Onera
//
//  Centralized button size, padding, and style tokens
//

import SwiftUI

// MARK: - Button Size Tokens

/// Onera Design System — Button Tokens
///
/// Consistent button dimensions used throughout the app.
/// All heights include built-in minimum touch target compliance.
enum OneraButton {
    
    // MARK: - Heights
    
    /// 32pt — Compact: icon-only buttons, inline actions
    static let heightSm: CGFloat = 32
    
    /// 44pt — Standard: matches Apple HIG minimum touch target
    static let heightMd: CGFloat = 44
    
    /// 50pt — Large: primary CTA buttons
    static let heightLg: CGFloat = 50
    
    /// 56pt — Extra large: full-width auth/onboarding buttons
    static let heightXl: CGFloat = 56
    
    // MARK: - Padding
    
    /// Compact horizontal padding (12pt)
    static let paddingHSm: CGFloat = 12
    
    /// Standard horizontal padding (16pt)
    static let paddingHMd: CGFloat = 16
    
    /// Generous horizontal padding (24pt)
    static let paddingHLg: CGFloat = 24
    
    /// Compact vertical padding (8pt)
    static let paddingVSm: CGFloat = 8
    
    /// Standard vertical padding (12pt)
    static let paddingVMd: CGFloat = 12
    
    /// Generous vertical padding (16pt)
    static let paddingVLg: CGFloat = 16
    
    // MARK: - Spacing
    
    /// Gap between icon and label inside a button (8pt)
    static let iconGap: CGFloat = 8
    
    /// Gap between buttons in a horizontal group (12pt)
    static let groupGap: CGFloat = 12
    
    /// Gap between buttons in a vertical stack (12pt)
    static let stackGap: CGFloat = 12
}

// MARK: - Primary Button Style

/// Full-width pill button — onboarding, auth, primary CTAs.
/// White background, black text. Adapts press state.
struct OneraPrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = .white
    var foregroundColor: Color = .black
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: OneraButton.heightXl)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

/// Full-width dark pill button — secondary CTAs (e.g., "Continue with Google").
struct OneraSecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: OneraButton.heightXl)
            .background(Color(white: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Pill Chip Style

/// Small pill chip button — quick actions, tags, filters.
struct OneraPillChipStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, OneraButton.paddingHMd)
            .padding(.vertical, OneraButton.paddingVSm)
            .background(Color(white: 0.18))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Ghost Button Style

/// Transparent button with text-only styling — tertiary actions.
struct OneraGhostButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(theme.accent)
            .frame(height: OneraButton.heightMd)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Destructive Button Style

/// Red-tinted button for destructive actions (delete, sign out).
struct OneraDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .frame(height: OneraButton.heightMd)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
