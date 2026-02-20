//
//  CaptionsDesignSystem.swift
//  Onera
//
//  Captions-inspired design system: gradient onboarding, dark home,
//  dark drawer, pill buttons, warm accents, generous spacing.
//
//  Note: CaptionsSpacing and CaptionsRadius have been removed.
//  All spacing/radius now use OneraSpacing / OneraRadius tokens.
//

import SwiftUI

// MARK: - Captions Color Palette (Onboarding Only)

/// Hardcoded colors for the Captions-style onboarding flow.
/// These exist because the onboarding gradient is brand-specific,
/// not theme-dependent. Everything else should use `@Environment(\.theme)`.
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
    static let darkBackground = Color(red: 0.07, green: 0.07, blue: 0.07)

    /// Elevated card / drawer background
    static let darkSurface = Color(red: 0.11, green: 0.11, blue: 0.11)

    /// Pill button / banner / input field background
    static let darkPill = Color(white: 0.18)

    /// Selected / highlighted row in the drawer
    static let darkSelected = Color(white: 0.22)

    // MARK: Bottom Sheet (Login card)

    /// The dark card that holds sign-in buttons
    static let sheetBackground = Color(red: 0.09, green: 0.09, blue: 0.09)

    // MARK: Text

    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.60)
    static let textTertiary = Color(white: 0.40)

    // MARK: Accents

    static let goldAccent = Color(red: 0.85, green: 0.68, blue: 0.30)
    static let profilePurple = Color(red: 0.62, green: 0.47, blue: 0.90)
    static let infoCyan = Color(red: 0.30, green: 0.75, blue: 0.95)
    static let ctaBlue = Color(red: 0.25, green: 0.52, blue: 0.96)

    // MARK: Borders

    static let subtleBorder = Color.white.opacity(0.08)
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
            .frame(height: OneraButton.heightXl)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
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
            .frame(height: OneraButton.heightXl)
            .background(pillColor)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
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
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
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
            HStack(spacing: OneraSpacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: OneraIconSize.md, height: OneraIconSize.md)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)

                Text(title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(
                isSelected
                    ? theme.onboardingSelected
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md, style: .continuous))
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
            .padding(.horizontal, OneraSpacing.md)
            .padding(.top, OneraSpacing.lg)
            .padding(.bottom, OneraSpacing.xs)
    }
}

// MARK: - Captions Profile Footer

struct CaptionsProfileFooter: View {
    let initial: String
    let name: String
    var subtitle: String = "Free"
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: OneraSpacing.sm) {
            // Avatar circle
            Text(initial)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(theme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: OneraSpacing.xxs) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, OneraSpacing.md)
        .padding(.vertical, OneraSpacing.sm)
    }
}

// MARK: - Captions Input Bar

/// Bottom text input bar matching the Captions style
struct CaptionsInputBarStyle: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.xl, style: .continuous))
            .padding(.horizontal, OneraSpacing.md)
            .padding(.bottom, OneraSpacing.xs)
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
        VStack(spacing: OneraSpacing.md) {
            // Gradient
            RoundedRectangle(cornerRadius: OneraRadius.xl)
                .fill(CaptionsColors.welcomeGradient)
                .frame(height: 200)
                .overlay(
                    Text("Welcome Gradient")
                        .font(.headline)
                        .foregroundStyle(.black)
                )

            // Dark surfaces
            HStack(spacing: OneraSpacing.xs) {
                colorSwatch("BG", CaptionsColors.darkBackground)
                colorSwatch("Surface", CaptionsColors.darkSurface)
                colorSwatch("Pill", CaptionsColors.darkPill)
                colorSwatch("Selected", CaptionsColors.darkSelected)
            }

            // Accents
            HStack(spacing: OneraSpacing.xs) {
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
    VStack(spacing: OneraSpacing.xxs) {
        RoundedRectangle(cornerRadius: OneraRadius.md)
            .fill(color)
            .frame(height: 50)
        Text(label)
            .font(.caption2)
            .foregroundStyle(.white)
    }
}
#endif
