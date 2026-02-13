//
//  CaptionsDesignSystem.swift
//  Onera
//
//  Captions-inspired design system: gradient onboarding, dark home,
//  dark drawer, pill buttons, warm accents, generous spacing.
//

import SwiftUI

// MARK: - Captions Color Palette

/// Design tokens inspired by the Captions app aesthetic
enum CaptionsColors {
    
    // MARK: Gradients
    
    /// Sky-blue → light peach gradient for onboarding / welcome background
    static let welcomeGradient = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.85, blue: 0.96),  // Sky blue
            Color(red: 0.76, green: 0.91, blue: 0.97),  // Pale cyan
            Color(red: 0.95, green: 0.88, blue: 0.84),  // Blush / peach
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: Dark Surfaces (Home / Drawer)
    
    /// Primary background – near-black warm charcoal
    static let darkBackground = Color(red: 0.07, green: 0.07, blue: 0.07)     // ~#121212
    
    /// Elevated card / drawer background
    static let darkSurface = Color(red: 0.11, green: 0.11, blue: 0.11)        // ~#1C1C1C
    
    /// Pill button / banner / input field background
    static let darkPill = Color(white: 0.18)                                   // ~#2E2E2E
    
    /// Selected / highlighted row in the drawer
    static let darkSelected = Color(white: 0.22)                               // ~#383838
    
    // MARK: Bottom Sheet (Login card)
    
    /// The dark card that holds sign-in buttons
    static let sheetBackground = Color(red: 0.09, green: 0.09, blue: 0.09)    // ~#171717
    
    // MARK: Text
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.60)                              // ~#999
    static let textTertiary = Color(white: 0.40)                               // ~#666
    
    // MARK: Accents
    
    /// Gold / amber accent (used for "Get MAX" style badges)
    static let goldAccent = Color(red: 0.85, green: 0.68, blue: 0.30)         // ~#D9AD4D
    
    /// Purple profile avatar accent
    static let profilePurple = Color(red: 0.62, green: 0.47, blue: 0.90)      // ~#9E78E6
    
    /// Cyan informational icon
    static let infoCyan = Color(red: 0.30, green: 0.75, blue: 0.95)           // ~#4DBFF2
    
    /// Standard blue for primary CTA buttons
    static let ctaBlue = Color(red: 0.25, green: 0.52, blue: 0.96)            // ~#4085F5
    
    // MARK: Borders
    
    static let subtleBorder = Color.white.opacity(0.08)
}

// MARK: - Captions Spacing

enum CaptionsSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Captions Radii

enum CaptionsRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 14
    static let large: CGFloat = 20
    static let sheet: CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - Captions Button Styles

/// Full-width pill button used on the login card (e.g. "Continue with Apple")
struct CaptionsPrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = .white
    var foregroundColor: Color = .black
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CaptionsRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Dark pill button used on the login card (e.g. "Continue with Google")
struct CaptionsDarkButtonStyle: ButtonStyle {
    var pillColor: Color = CaptionsColors.darkPill
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(pillColor)
            .clipShape(RoundedRectangle(cornerRadius: CaptionsRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Small pill chip button (e.g. "Import video", "AI Edit")
struct CaptionsPillChipStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(CaptionsColors.textPrimary)
            .padding(.horizontal, CaptionsSpacing.md)
            .padding(.vertical, CaptionsSpacing.sm)
            .background(CaptionsColors.darkPill)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Captions Drawer Row

/// A single row in the Captions-style side drawer
struct CaptionsDrawerRow: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var action: () -> Void = {}
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: CaptionsSpacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                
                Text(title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, CaptionsSpacing.md)
            .padding(.vertical, CaptionsSpacing.sm)
            .background(
                isSelected
                    ? theme.onboardingSelected
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: CaptionsRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Captions Section Header

struct CaptionsSectionHeader: View {
    let title: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.textTertiary)
            .tracking(1.2)
            .padding(.horizontal, CaptionsSpacing.md)
            .padding(.top, CaptionsSpacing.lg)
            .padding(.bottom, CaptionsSpacing.xs)
    }
}

// MARK: - Captions Profile Footer

struct CaptionsProfileFooter: View {
    let initial: String
    let name: String
    var subtitle: String = "Free"
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: CaptionsSpacing.sm) {
            // Avatar circle
            Text(initial)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(theme.accent)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, CaptionsSpacing.md)
        .padding(.vertical, CaptionsSpacing.sm)
    }
}

// MARK: - Captions Input Bar

/// Bottom text input bar matching the Captions style
struct CaptionsInputBarStyle: ViewModifier {
    @Environment(\.theme) private var theme
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CaptionsSpacing.md)
            .padding(.vertical, CaptionsSpacing.sm)
            .background(theme.onboardingPill)
            .clipShape(RoundedRectangle(cornerRadius: CaptionsRadius.large, style: .continuous))
            .padding(.horizontal, CaptionsSpacing.md)
            .padding(.bottom, CaptionsSpacing.xs)
    }
}

extension View {
    func captionsInputBarStyle() -> some View {
        modifier(CaptionsInputBarStyle())
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Captions Colors") {
    ScrollView {
        VStack(spacing: 16) {
            // Gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(CaptionsColors.welcomeGradient)
                .frame(height: 200)
                .overlay(
                    Text("Welcome Gradient")
                        .font(.headline)
                        .foregroundStyle(.black)
                )
            
            // Dark surfaces
            HStack(spacing: 8) {
                colorSwatch("BG", CaptionsColors.darkBackground)
                colorSwatch("Surface", CaptionsColors.darkSurface)
                colorSwatch("Pill", CaptionsColors.darkPill)
                colorSwatch("Selected", CaptionsColors.darkSelected)
            }
            
            // Accents
            HStack(spacing: 8) {
                colorSwatch("Gold", CaptionsColors.goldAccent)
                colorSwatch("Purple", CaptionsColors.profilePurple)
                colorSwatch("Cyan", CaptionsColors.infoCyan)
                colorSwatch("Blue", CaptionsColors.ctaBlue)
            }
        }
        .padding()
    }
    .background(CaptionsColors.darkBackground)
}

private func colorSwatch(_ label: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(height: 50)
        Text(label)
            .font(.caption2)
            .foregroundStyle(.white)
    }
}
#endif
