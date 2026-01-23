//
//  OnboardingView.swift
//  Onera
//
//  Native iOS onboarding flow for new users
//

import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case apiKeys
    case encryption
    case providers
    case recovery
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Onera"
        case .apiKeys: return "Your API Keys"
        case .encryption: return "End-to-End Encrypted"
        case .providers: return "Cloud or Local"
        case .recovery: return "Recovery Key"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome: return "Private AI chat, built differently"
        case .apiKeys: return "You control which AI providers to use"
        case .encryption: return "Your conversations stay private"
        case .providers: return "Choose your privacy level"
        case .recovery: return "The key to your encrypted data"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .apiKeys: return "key.fill"
        case .encryption: return "lock.shield.fill"
        case .providers: return "server.rack"
        case .recovery: return "lock.doc.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome: return .blue
        case .apiKeys: return .orange
        case .encryption: return .green
        case .providers: return .purple
        case .recovery: return .red
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    
    @State private var currentStep: OnboardingStep = .welcome
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Native page control
            TabView(selection: $currentStep) {
                ForEach(OnboardingStep.allCases) { step in
                    OnboardingPageView(step: step)
                        .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    if currentStep == .recovery {
                        onComplete()
                    } else {
                        withAnimation {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .recovery
                        }
                    }
                } label: {
                    Text(currentStep == .recovery ? "Get Started" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if currentStep != .recovery {
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
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Onboarding Page View

private struct OnboardingPageView: View {
    let step: OnboardingStep
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
                // Icon
                Image(systemName: step.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(step.iconColor)
                    .frame(width: 100, height: 100)
                    .background(step.iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Title and subtitle
                VStack(spacing: 12) {
                    Text(step.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(step.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Step-specific content
                Group {
                    switch step {
                    case .welcome:
                        WelcomeContent()
                    case .apiKeys:
                        ApiKeysContent()
                    case .encryption:
                        EncryptionContent()
                    case .providers:
                        ProvidersContent()
                    case .recovery:
                        RecoveryContent()
                    }
                }
                .padding(.top, 8)
                
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
        VStack(spacing: 16) {
            FeatureRow(icon: "key.fill", title: "Bring Your Own Keys", subtitle: "Use your own API keys")
            FeatureRow(icon: "lock.shield.fill", title: "End-to-End Encrypted", subtitle: "We can't read your chats")
            FeatureRow(icon: "desktopcomputer", title: "Local AI Support", subtitle: "Run models on your device")
        }
    }
}

// MARK: - API Keys Content

private struct ApiKeysContent: View {
    var body: some View {
        VStack(spacing: 16) {
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Your keys, your control",
                description: "API keys are encrypted and stored on your device"
            )
            
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Pay providers directly",
                description: "We never proxy your API requests"
            )
            
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Multiple providers",
                description: "OpenAI, Anthropic, and local Ollama"
            )
        }
    }
}

// MARK: - Encryption Content

private struct EncryptionContent: View {
    var body: some View {
        VStack(spacing: 20) {
            // Visual flow
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                    Text("Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Encrypt")
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Standards
            HStack(spacing: 12) {
                StandardBadge(name: "AES-256", description: "Encryption")
                StandardBadge(name: "Argon2id", description: "Key derivation")
            }
        }
    }
}

// MARK: - Providers Content

private struct ProvidersContent: View {
    var body: some View {
        VStack(spacing: 16) {
            ProviderCard(
                icon: "cloud.fill",
                iconColor: .blue,
                title: "Cloud Providers",
                description: "GPT-4, Claude, and more via your API keys",
                badge: "Popular"
            )
            
            ProviderCard(
                icon: "desktopcomputer",
                iconColor: .green,
                title: "Local with Ollama",
                description: "Run AI completely offline on your device",
                badge: "Most Private"
            )
        }
    }
}

// MARK: - Recovery Content

private struct RecoveryContent: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("It's your master key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("This phrase decrypts all your data")
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
                        Text("We can't reset it")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("Only you have access to your data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "xmark.shield.fill")
                        .foregroundStyle(.red)
                }
                
                Divider()
                
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Store it safely")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("Write it down or use a password manager")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.doc.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Text("You'll receive your recovery phrase next.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helper Views

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StandardBadge: View {
    let name: String
    let description: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(Color(.label))
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColor.opacity(0.15))
                            .foregroundStyle(iconColor)
                            .clipShape(Capsule())
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Previews

#Preview {
    OnboardingView(onComplete: {})
}
