//
//  AddApiKeyPromptView.swift
//  Onera
//
//  Provider selection grid for adding API credentials
//  Matches web app's ConnectionsTab style
//

import SwiftUI

struct AddApiKeyPromptView: View {
    
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    
    let onSelectProvider: (LLMProvider) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.largeTitle)
                            .foregroundStyle(theme.warning)
                        
                        VStack(spacing: 8) {
                            Text("Add Your First API Key")
                                .font(.title2.bold())
                            
                            Text("Connect an AI provider to start chatting")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                }
                
                // Popular Providers
                Section {
                    ProviderButton(
                        provider: .openai,
                        description: "GPT-4o, o1, o3",
                        icon: "sparkles",
                        iconColor: .green,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .anthropic,
                        description: "Claude 4, Claude 3.7",
                        icon: "brain.head.profile",
                        iconColor: .orange,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .google,
                        description: "Gemini 2.0, Gemini 1.5",
                        icon: "g.circle.fill",
                        iconColor: .blue,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .xai,
                        description: "Grok 2, Grok 3",
                        icon: "x.circle.fill",
                        iconColor: Color.primary,
                        onSelect: onSelectProvider
                    )
                } header: {
                    Text("Popular")
                }
                
                // Open Source
                Section {
                    ProviderButton(
                        provider: .groq,
                        description: "Ultra-fast Llama, Mixtral",
                        icon: "bolt.fill",
                        iconColor: .orange,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .mistral,
                        description: "Mistral Large, Codestral",
                        icon: "wind",
                        iconColor: .blue,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .deepseek,
                        description: "DeepSeek V3, DeepSeek-R1",
                        icon: "magnifyingglass",
                        iconColor: .purple,
                        onSelect: onSelectProvider
                    )
                } header: {
                    Text("Open Source")
                }
                
                // Aggregators
                Section {
                    ProviderButton(
                        provider: .openrouter,
                        description: "200+ models, one API",
                        icon: "arrow.triangle.branch",
                        iconColor: .pink,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .together,
                        description: "Llama, Qwen, and more",
                        icon: "person.2.fill",
                        iconColor: .blue,
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .fireworks,
                        description: "Fast inference",
                        icon: "flame.fill",
                        iconColor: .orange,
                        onSelect: onSelectProvider
                    )
                } header: {
                    Text("Aggregators")
                }
                
                // Local
                Section {
                    ProviderButton(
                        provider: .ollama,
                        description: "Run models locally",
                        icon: "desktopcomputer",
                        iconColor: .green,
                        badge: "No API Key",
                        onSelect: onSelectProvider
                    )
                    
                    ProviderButton(
                        provider: .lmstudio,
                        description: "Local LM Studio server",
                        icon: "server.rack",
                        iconColor: .purple,
                        badge: "No API Key",
                        onSelect: onSelectProvider
                    )
                } header: {
                    Text("Local")
                } footer: {
                    Text("Run AI completely offline on your own hardware.")
                }
                
                // Skip
                Section {
                    Button("I'll do this later") {
                        onSkip()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(theme.textSecondary)
                } footer: {
                    Text("You can add API keys anytime in Settings.")
                }
            }
            .navigationTitle("Add Connection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Provider Button

private struct ProviderButton: View {
    let provider: LLMProvider
    let description: String
    let icon: String
    let iconColor: Color
    var badge: String? = nil
    let onSelect: (LLMProvider) -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button {
            onSelect(provider)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(provider.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.success.opacity(0.15))
                                .foregroundStyle(theme.success)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }
}

// MARK: - LLMProvider Extension

extension LLMProvider {
    var apiKeyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .google: return "AI..."
        case .xai: return "xai-..."
        case .groq: return "gsk_..."
        case .mistral: return ""
        case .deepseek: return "sk-..."
        case .openrouter: return "sk-or-..."
        case .together: return ""
        case .fireworks: return "fw_..."
        case .ollama, .lmstudio, .custom, .private: return ""
        }
    }
    
    var websiteURL: URL? {
        switch self {
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .google: return URL(string: "https://aistudio.google.com/apikey")
        case .xai: return URL(string: "https://console.x.ai")
        case .groq: return URL(string: "https://console.groq.com/keys")
        case .mistral: return URL(string: "https://console.mistral.ai/api-keys")
        case .deepseek: return URL(string: "https://platform.deepseek.com/api_keys")
        case .openrouter: return URL(string: "https://openrouter.ai/keys")
        case .together: return URL(string: "https://api.together.xyz/settings/api-keys")
        case .fireworks: return URL(string: "https://fireworks.ai/api-keys")
        case .ollama: return URL(string: "https://ollama.ai")
        case .lmstudio: return URL(string: "https://lmstudio.ai")
        case .custom, .private: return nil
        }
    }
}

// MARK: - Previews

#Preview {
    AddApiKeyPromptView(
        onSelectProvider: { _ in },
        onSkip: {}
    )
}
