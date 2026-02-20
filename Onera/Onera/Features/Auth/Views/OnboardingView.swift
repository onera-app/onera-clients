//
//  OnboardingView.swift
//  Onera
//
//  Post-auth onboarding: security education and setup overview.
//  Gradient background with dark bottom card. Colours from ThemeColors.
//

import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case security
    case ready
    
    var id: Int { rawValue }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    
    @State private var currentStep: OnboardingStep = .security
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
                        OneraIcon.info.solidImage
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

// MARK: - Security Branding

private struct SecurityBrandingContent: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: OneraSpacing.xxl) {
            OneraIcon.shield.solidImage
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
                OneraIcon.forward.image
                    .foregroundStyle(theme.onboardingTextTertiary)
                encryptionNode(icon: "lock.fill", label: "Encrypted")
                OneraIcon.forward.image
                    .foregroundStyle(theme.onboardingTextTertiary)
                encryptionNode(icon: "icloud.fill", label: "Stored")
            }
            .padding()
            .background(theme.onboardingTextPrimary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
        }
    }
    
    private func encryptionNode(icon: String, label: String) -> some View {
        VStack(spacing: OneraSpacing.xxs) {
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
            OneraIcon.verified.image
                .font(.system(size: 56))
                .foregroundStyle(theme.onboardingTextPrimary.opacity(0.75))
            
            VStack(spacing: OneraSpacing.md) {
                Text("You're All Set")
                    .font(.title.bold())
                    .foregroundStyle(theme.onboardingTextPrimary)
                
                Text("Set up encryption and add your API keys to get started.")
                    .font(.body)
                    .foregroundStyle(theme.onboardingTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: OneraSpacing.md) {
                readyStep(number: 1, title: "Set Up Encryption", subtitle: "Create passkey or password")
                readyStep(number: 2, title: "Add API Key", subtitle: "Connect to an AI provider")
            }
        }
    }
    
    private func readyStep(number: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: OneraSpacing.lg) {
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.textOnAccent)
                .frame(width: OneraIconSize.xl, height: OneraIconSize.xl)
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
        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md, style: .continuous))
    }
}

// MARK: - Previews

#Preview {
    OnboardingView(onComplete: {})
        .themed()
}
