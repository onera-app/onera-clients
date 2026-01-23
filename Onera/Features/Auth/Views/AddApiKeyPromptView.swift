//
//  AddApiKeyPromptView.swift
//  Onera
//
//  Native iOS view prompting user to add their first API key
//

import SwiftUI

struct AddApiKeyPromptView: View {
    
    @Environment(\.openURL) private var openURL
    
    let onAddKey: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.orange)
                        
                        VStack(spacing: 8) {
                            Text("Add Your First API Key")
                                .font(.title2.bold())
                            
                            Text("Connect an AI provider to start chatting")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
                }
                
                Section {
                    // OpenAI
                    ProviderRow(
                        name: "OpenAI",
                        description: "GPT-4, GPT-4o, and more",
                        icon: "sparkles",
                        iconColor: .green,
                        url: "https://platform.openai.com/api-keys"
                    )
                    
                    // Anthropic
                    ProviderRow(
                        name: "Anthropic",
                        description: "Claude 3.5 Sonnet, Opus",
                        icon: "brain.head.profile",
                        iconColor: .orange,
                        url: "https://console.anthropic.com/settings/keys"
                    )
                    
                    // Local
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local with Ollama")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(.label))
                            Text("No API key needed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("Free")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                } header: {
                    Text("Supported Providers")
                } footer: {
                    Text("Your API keys are encrypted and stored only on your device. We never see them.")
                }
                
                Section {
                    Button("Add API Key") {
                        onAddKey()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section {
                    Button("I'll do this later") {
                        onSkip()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    @Environment(\.openURL) private var openURL
    
    let name: String
    let description: String
    let icon: String
    let iconColor: Color
    let url: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(.label))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                if let url = URL(string: url) {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Previews

#Preview {
    AddApiKeyPromptView(
        onAddKey: {},
        onSkip: {}
    )
}
