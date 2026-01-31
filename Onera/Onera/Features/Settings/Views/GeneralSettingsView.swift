//
//  GeneralSettingsView.swift
//  Onera
//
//  General settings for model parameters and system prompt
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @Environment(\.theme) private var theme
    @AppStorage("systemPrompt") private var systemPrompt = ""
    @AppStorage("streamResponse") private var streamResponse = true
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("topP") private var topP = 1.0
    @AppStorage("topK") private var topK = 40
    @AppStorage("maxTokens") private var maxTokens = 0
    @AppStorage("frequencyPenalty") private var frequencyPenalty = 0.0
    @AppStorage("presencePenalty") private var presencePenalty = 0.0
    
    // Provider-specific settings
    @AppStorage("openai.reasoningEffort") private var openAIReasoningEffort = "medium"
    @AppStorage("anthropic.extendedThinking") private var anthropicExtendedThinking = false
    
    @State private var showAdvanced = false
    @State private var showProviderSettings = false
    
    var body: some View {
        List {
            systemPromptSection
            streamingSection
            providerSettingsSection
            advancedParametersSection
        }
        .navigationTitle("General")
    }
    
    // MARK: - System Prompt Section
    
    private var systemPromptSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("System Prompt")
                    .font(.headline)
                
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 100)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("This prompt is sent at the beginning of every conversation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Streaming Section
    
    private var streamingSection: some View {
        Section {
            Toggle(isOn: $streamResponse) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stream Response")
                    Text("Show responses as they're generated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Provider Settings Section
    
    private var providerSettingsSection: some View {
        Section {
            DisclosureGroup("Provider Settings", isExpanded: $showProviderSettings) {
                // OpenAI Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("Reasoning Effort", selection: $openAIReasoningEffort) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    
                    Text("Controls reasoning for o1, o3, and gpt-5 models")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // Anthropic Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anthropic")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Toggle(isOn: $anthropicExtendedThinking) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Extended Thinking")
                            Text("Enable extended thinking for Claude models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Advanced Parameters Section
    
    private var advancedParametersSection: some View {
        Section {
            DisclosureGroup("Advanced Parameters", isExpanded: $showAdvanced) {
                // Temperature
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", temperature))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $temperature, in: 0...2, step: 0.01)
                    Text("Higher values make output more random, lower values more focused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Top P
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top P (Nucleus Sampling)")
                        Spacer()
                        Text(String(format: "%.2f", topP))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $topP, in: 0...1, step: 0.01)
                    Text("Consider tokens with top_p probability mass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Top K
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top K")
                        Spacer()
                        Text("\(topK)")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(topK) },
                        set: { topK = Int($0) }
                    ), in: 1...100, step: 1)
                    Text("Consider only top K tokens for each step")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Max Tokens
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        TextField("Default", value: $maxTokens, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("Maximum tokens to generate (0 for model default)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Frequency Penalty
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Frequency Penalty")
                        Spacer()
                        Text(String(format: "%.2f", frequencyPenalty))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $frequencyPenalty, in: -2...2, step: 0.01)
                    Text("Reduce repetition of frequent tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Presence Penalty
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Presence Penalty")
                        Spacer()
                        Text(String(format: "%.2f", presencePenalty))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $presencePenalty, in: -2...2, step: 0.01)
                    Text("Encourage talking about new topics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Reset Button
                Button {
                    resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func resetToDefaults() {
        temperature = 0.7
        topP = 1.0
        topK = 40
        maxTokens = 0
        frequencyPenalty = 0.0
        presencePenalty = 0.0
        openAIReasoningEffort = "medium"
        anthropicExtendedThinking = false
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
}
#endif
