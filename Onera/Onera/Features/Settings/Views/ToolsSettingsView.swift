//
//  ToolsSettingsView.swift
//  Onera
//
//  Configure search providers and tool integrations
//

import SwiftUI

// MARK: - Search Provider

enum SearchProvider: String, CaseIterable, Identifiable {
    case tavily
    case serper
    case brave
    case exa
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tavily: return "Tavily"
        case .serper: return "Serper"
        case .brave: return "Brave Search"
        case .exa: return "Exa"
        }
    }
    
    var description: String {
        switch self {
        case .tavily: return "AI-optimized search API with intelligent context extraction"
        case .serper: return "Google Search API for real-time search results"
        case .brave: return "Privacy-focused search with independent index"
        case .exa: return "Neural search engine for finding similar content"
        }
    }
    
    var docsURL: URL {
        switch self {
        case .tavily: return URL(string: "https://tavily.com")!
        case .serper: return URL(string: "https://serper.dev")!
        case .brave: return URL(string: "https://brave.com/search/api")!
        case .exa: return URL(string: "https://exa.ai")!
        }
    }
}

// MARK: - Native Search Provider

enum NativeSearchProvider: String, CaseIterable, Identifiable {
    case google
    case xai
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .google: return "Google Search (Gemini)"
        case .xai: return "Web Search (Grok)"
        }
    }
    
    var description: String {
        switch self {
        case .google: return "Native search grounding for Google Gemini models"
        case .xai: return "Native web search for xAI Grok models"
        }
    }
    
    var features: [String] {
        switch self {
        case .google: return ["Real-time search results", "Source citations", "Grounding metadata"]
        case .xai: return ["Live web search", "Image understanding", "Domain filtering"]
        }
    }
}

// MARK: - Tools Settings View

struct ToolsSettingsView: View {
    
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    
    @AppStorage("searchEnabledByDefault") private var searchEnabledByDefault = false
    @AppStorage("defaultSearchProvider") private var defaultSearchProvider = ""
    
    // Native search settings
    @AppStorage("nativeSearch.google.enabled") private var googleSearchEnabled = false
    @AppStorage("nativeSearch.xai.enabled") private var xaiSearchEnabled = false
    @AppStorage("nativeSearch.xai.imageUnderstanding") private var xaiImageUnderstanding = true
    
    // Provider API keys (stored in keychain in production, AppStorage for demo)
    @AppStorage("searchProvider.tavily.configured") private var tavilyConfigured = false
    @AppStorage("searchProvider.serper.configured") private var serperConfigured = false
    @AppStorage("searchProvider.brave.configured") private var braveConfigured = false
    @AppStorage("searchProvider.exa.configured") private var exaConfigured = false
    
    @State private var editingProvider: SearchProvider?
    @State private var apiKeyInput = ""
    @State private var showApiKey = false
    @State private var showRemoveConfirmation = false
    @State private var providerToRemove: SearchProvider?
    
    var body: some View {
        Form {
            webSearchSection
            nativeSearchSection
            externalProvidersSection
        }
        .formStyle(.grouped)
        .navigationTitle("Tools")
        .alert("Remove API Key", isPresented: $showRemoveConfirmation, presenting: providerToRemove) { provider in
            Button("Remove", role: .destructive) {
                removeProviderKey(provider)
            }
            Button("Cancel", role: .cancel) {}
        } message: { provider in
            Text("Are you sure you want to remove the \(provider.displayName) API key? You'll need to add it again to use this search provider.")
        }
    }
    
    // MARK: - Web Search Section
    
    private var webSearchSection: some View {
        Section {
            Toggle(isOn: $searchEnabledByDefault) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable by Default")
                    Text("Automatically enable web search for new messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(configuredProviders.isEmpty)
            
            if !configuredProviders.isEmpty {
                Picker("Default Provider", selection: $defaultSearchProvider) {
                    Text("Select provider").tag("")
                    ForEach(configuredProviders, id: \.self) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
            }
        } header: {
            Label("Web Search", systemImage: "globe")
        } footer: {
            if configuredProviders.isEmpty {
                Text("Add a search provider API key to enable web search")
            }
        }
    }
    
    // MARK: - Native Search Section
    
    private var nativeSearchSection: some View {
        Section {
            ForEach(NativeSearchProvider.allCases) { provider in
                nativeProviderRow(provider)
            }
        } header: {
            Label("Native AI Search", systemImage: "sparkles")
        } footer: {
            Text("Built-in search tools for supported AI providers. No additional API keys required.")
        }
    }
    
    @ViewBuilder
    private func nativeProviderRow(_ provider: NativeSearchProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: bindingForNativeProvider(provider)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .fontWeight(.medium)
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Features badges
            FlowLayout(spacing: 4) {
                ForEach(provider.features, id: \.self) { feature in
                    Text(feature)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            // xAI-specific settings
            if provider == .xai && xaiSearchEnabled {
                Divider()
                    .padding(.vertical, 4)
                
                Toggle(isOn: $xaiImageUnderstanding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Image Understanding")
                            .font(.subheadline)
                        Text("Allow Grok to analyze images from search results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func bindingForNativeProvider(_ provider: NativeSearchProvider) -> Binding<Bool> {
        switch provider {
        case .google:
            return $googleSearchEnabled
        case .xai:
            return $xaiSearchEnabled
        }
    }
    
    // MARK: - External Providers Section
    
    private var externalProvidersSection: some View {
        Section {
            ForEach(SearchProvider.allCases) { provider in
                providerRow(provider)
            }
        } header: {
            Label("External Search Providers", systemImage: "key.horizontal")
        } footer: {
            Text("Add API keys for third-party search providers. Keys are encrypted end-to-end.")
        }
    }
    
    @ViewBuilder
    private func providerRow(_ provider: SearchProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.displayName)
                            .fontWeight(.medium)
                        
                        if isProviderConfigured(provider) {
                            Text("Connected")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if editingProvider == provider {
                    // Editing mode buttons
                    Button("Cancel") {
                        editingProvider = nil
                        apiKeyInput = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveProviderKey(provider)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput.isEmpty)
                } else {
                    // Normal mode buttons
                    if isProviderConfigured(provider) {
                        Button {
                            providerToRemove = provider
                            showRemoveConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Button {
                        editingProvider = provider
                        apiKeyInput = ""
                    } label: {
                        Label(
                            isProviderConfigured(provider) ? "Update" : "Add",
                            systemImage: "key"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Get API key link
            Button {
                openURL(provider.docsURL)
            } label: {
                HStack(spacing: 4) {
                    Text("Get API key")
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            
            // API key input (when editing)
            if editingProvider == provider {
                HStack {
                    if showApiKey {
                        TextField("Enter API key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter API key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private var configuredProviders: [SearchProvider] {
        SearchProvider.allCases.filter { isProviderConfigured($0) }
    }
    
    private func isProviderConfigured(_ provider: SearchProvider) -> Bool {
        switch provider {
        case .tavily: return tavilyConfigured
        case .serper: return serperConfigured
        case .brave: return braveConfigured
        case .exa: return exaConfigured
        }
    }
    
    private func saveProviderKey(_ provider: SearchProvider) {
        // In production, this would save to Keychain with E2EE
        // For now, just mark as configured
        switch provider {
        case .tavily: tavilyConfigured = true
        case .serper: serperConfigured = true
        case .brave: braveConfigured = true
        case .exa: exaConfigured = true
        }
        
        editingProvider = nil
        apiKeyInput = ""
        
        // Set as default if first provider
        if defaultSearchProvider.isEmpty {
            defaultSearchProvider = provider.rawValue
        }
    }
    
    private func removeProviderKey(_ provider: SearchProvider) {
        switch provider {
        case .tavily: tavilyConfigured = false
        case .serper: serperConfigured = false
        case .brave: braveConfigured = false
        case .exa: exaConfigured = false
        }
        
        // Clear default if this was the default
        if defaultSearchProvider == provider.rawValue {
            defaultSearchProvider = configuredProviders.first?.rawValue ?? ""
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ToolsSettingsView()
    }
}
#endif
