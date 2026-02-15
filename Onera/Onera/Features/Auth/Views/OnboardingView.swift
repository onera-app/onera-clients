//
//  OnboardingView.swift
//  Onera
//
//  Captions-inspired onboarding: gradient background, centered branding,
//  dark bottom card with sign-in buttons. All colours sourced from ThemeColors.
//

import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case security
    case ready
    
    var id: Int { rawValue }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    
    @State private var currentStep: OnboardingStep = .welcome
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.theme) private var theme
    
    let onComplete: () -> Void
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private let iPadMaxWidth: CGFloat = 600
    
    var body: some View {
        ZStack {
            theme.onboardingGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        // Help action
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.onboardingTextPrimary.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Help")
                }
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.top, OneraSpacing.sm)
                
                Spacer()
                
                VStack(spacing: OneraSpacing.lg) {
                    switch currentStep {
                    case .welcome:
                        WelcomeBrandingContent()
                    case .security:
                        SecurityBrandingContent()
                    case .ready:
                        ReadyBrandingContent(theme: theme)
                    }
                }
                .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
                .padding(.horizontal, OneraSpacing.xxxl)
                
                Spacer()
                
                bottomCard
            }
        }
    }
    
    // MARK: - Bottom Dark Card
    
    private var bottomCard: some View {
        VStack(spacing: OneraSpacing.lg) {
            if currentStep == .ready {
                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                }
                .buttonStyle(CaptionsPrimaryButtonStyle())
                
            } else if currentStep == .welcome {
                Button {
                    advanceOrComplete()
                } label: {
                    HStack(spacing: OneraSpacing.md) {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        Text("Continue with Apple")
                    }
                }
                .buttonStyle(CaptionsPrimaryButtonStyle())
                
                Button {
                    advanceOrComplete()
                } label: {
                    HStack(spacing: OneraSpacing.md) {
                        Image(systemName: "globe")
                            .font(.title3)
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(CaptionsDarkButtonStyle())
                
                Button {
                    advanceOrComplete()
                } label: {
                    Text("Continue another way")
                        .font(.subheadline)
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.top, OneraSpacing.sm)
                
            } else {
                Button {
                    advanceOrComplete()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(CaptionsPrimaryButtonStyle())
                
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
        .padding(.horizontal, OneraSpacing.xxl)
        .padding(.top, OneraSpacing.xxxl)
        .padding(.bottom, OneraSpacing.xxxl)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: OneraRadius.pill,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: OneraRadius.pill
            )
            .fill(theme.onboardingSheetBackground)
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func advanceOrComplete() {
        if currentStep == .ready {
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .ready
            }
        }
    }
}

// MARK: - Welcome Branding

private struct WelcomeBrandingContent: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: OneraSpacing.md) {
            Text("onera")
                .font(.system(size: 52, weight: .bold, design: .default))
                .foregroundStyle(theme.onboardingTextPrimary)
            
            Text("Private AI chat, built differently.")
                .font(.title3)
                .foregroundStyle(theme.onboardingTextSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Security Branding

private struct SecurityBrandingContent: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: OneraSpacing.xxl) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.onboardingTextPrimary.opacity(0.75))
            
            VStack(spacing: OneraSpacing.md) {
                Text("Your Data, Your Control")
                    .font(.title.bold())
                    .foregroundStyle(theme.onboardingTextPrimary)
                
                Text("Everything is encrypted before it leaves your device. We never see your chats or API keys.")
                    .font(.body)
                    .foregroundStyle(theme.onboardingTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: OneraSpacing.lg) {
                encryptionNode(icon: "doc.text", label: "Your Data")
                Image(systemName: "arrow.right")
                    .foregroundStyle(theme.onboardingTextTertiary)
                encryptionNode(icon: "lock.fill", label: "Encrypted")
                Image(systemName: "arrow.right")
                    .foregroundStyle(theme.onboardingTextTertiary)
                encryptionNode(icon: "icloud.fill", label: "Stored")
            }
            .padding()
            .background(theme.onboardingTextPrimary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.medium, style: .continuous))
        }
    }
    
    private func encryptionNode(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(theme.onboardingTextPrimary.opacity(0.7))
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.onboardingTextTertiary)
        }
    }
}

// MARK: - Ready Branding

private struct ReadyBrandingContent: View {
    let theme: ThemeColors
    
    var body: some View {
        VStack(spacing: OneraSpacing.xxl) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.onboardingTextPrimary.opacity(0.75))
            
            VStack(spacing: OneraSpacing.md) {
                Text("You're All Set")
                    .font(.title.bold())
                    .foregroundStyle(theme.onboardingTextPrimary)
                
                Text("Sign in, set up encryption, and add your API keys to get started.")
                    .font(.body)
                    .foregroundStyle(theme.onboardingTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: OneraSpacing.md) {
                readyStep(number: 1, title: "Sign In", subtitle: "Use Apple or Google")
                readyStep(number: 2, title: "Set Up Encryption", subtitle: "Create passkey or password")
                readyStep(number: 3, title: "Add API Key", subtitle: "Connect to an AI provider")
            }
        }
    }
    
    private func readyStep(number: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: OneraSpacing.lg) {
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(theme.onboardingTextPrimary.opacity(0.7))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onboardingTextPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.onboardingTextTertiary)
            }
            
            Spacer()
        }
        .padding()
        .background(theme.onboardingTextPrimary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.standard, style: .continuous))
    }
}

// MARK: - Previews

#Preview {
    OnboardingView(onComplete: {})
        .themed()
}
