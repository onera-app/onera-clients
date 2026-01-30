//
//  OnboardingView.swift
//  Onera
//
//  Streamlined native iOS onboarding flow
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
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(OnboardingStep.allCases) { step in
                    OnboardingPageView(step: step)
                        .tag(step)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif
            
            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    if currentStep == .ready {
                        onComplete()
                    } else {
                        withAnimation {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .ready
                        }
                    }
                } label: {
                    Text(currentStep == .ready ? "Get Started" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                
                if currentStep != .ready {
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(OneraColors.background)
    }
}

// MARK: - Onboarding Page View

private struct OnboardingPageView: View {
    let step: OnboardingStep
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
                switch step {
                case .welcome:
                    WelcomeContent()
                case .security:
                    SecurityContent()
                case .ready:
                    ReadyContent()
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Welcome Content

private struct WelcomeContent: View {
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .frame(width: 100, height: 100)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            VStack(spacing: 12) {
                Text("Welcome to Onera")
                    .font(.title.bold())
                
                Text("Private AI chat, built differently")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "key.fill",
                    iconColor: .orange,
                    title: "Bring Your Own Keys",
                    subtitle: "Use your own API keys from OpenAI, Anthropic, and more"
                )
                
                FeatureRow(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "End-to-End Encrypted",
                    subtitle: "Your chats and API keys are encrypted—we can't read them"
                )
                
                FeatureRow(
                    icon: "desktopcomputer",
                    iconColor: .purple,
                    title: "Local AI Support",
                    subtitle: "Run models completely offline with Ollama"
                )
            }
        }
    }
}

// MARK: - Security Content

private struct SecurityContent: View {
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .frame(width: 100, height: 100)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            VStack(spacing: 12) {
                Text("Your Data, Your Control")
                    .font(.title.bold())
                
                Text("Everything is encrypted before it leaves your device")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Encryption visual
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                    Text("Your Data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Encrypted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    Image(systemName: "icloud.fill")
                        .font(.title2)
                    Text("Stored")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(OneraColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Recovery key info
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recovery Phrase")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("You'll get a 24-word phrase to backup your encryption key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.orange)
                }
                
                Divider()
                
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("We Can't Reset It")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("This is by design—only you have access to your data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(OneraColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Ready Content

private struct ReadyContent: View {
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .frame(width: 100, height: 100)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            VStack(spacing: 12) {
                Text("You're All Set")
                    .font(.title.bold())
                
                Text("After signing in, you'll set up encryption and add your API keys")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                StepRow(number: 1, title: "Sign In", subtitle: "Use Apple or Google")
                StepRow(number: 2, title: "Set Up Encryption", subtitle: "Create passkey or password")
                StepRow(number: 3, title: "Add API Key", subtitle: "Connect to an AI provider")
            }
        }
    }
}

// MARK: - Helper Views

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(OneraColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(OneraColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Previews

#Preview {
    OnboardingView(onComplete: {})
}
