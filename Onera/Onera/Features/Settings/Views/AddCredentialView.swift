//
//  AddCredentialView.swift
//  Onera
//
//  Form to add a new API credential
//  Native iOS design matching web app functionality
//

import SwiftUI

struct AddCredentialView: View {
    
    @Bindable var viewModel: CredentialsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    @FocusState private var focusedField: Field?
    
    /// Optional: Pre-select a provider (for use from onboarding)
    var selectedProvider: LLMProvider?
    /// Optional: Callback when credential is saved
    var onSave: (() -> Void)?
    /// Optional: Callback when cancelled
    var onCancel: (() -> Void)?
    
    /// Tracks whether the user has acknowledged the third-party data sharing disclosure
    @AppStorage("hasAcknowledgedAIDataSharing") private var hasAcknowledgedAIDataSharing = false
    @State private var showDataSharingDisclosure = false
    
    private enum Field: Hashable {
        case name, apiKey, baseUrl, orgId
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Provider info header
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: iconForProvider(viewModel.selectedProvider))
                            .font(.title)
                            .foregroundStyle(colorForProvider(viewModel.selectedProvider))
                            .frame(width: 44, height: 44)
                            .background(colorForProvider(viewModel.selectedProvider).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedProvider.displayName)
                                .font(.headline)
                            Text(descriptionForProvider(viewModel.selectedProvider))
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if let url = viewModel.selectedProvider.websiteURL {
                            Button {
                                openURL(url)
                            } label: {
                                OneraIcon.openExternal.image
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                }
                
                // Connection name
                Section {
                    TextField(
                        "Connection Name",
                        text: $viewModel.credentialName,
                        prompt: Text("My \(viewModel.selectedProvider.displayName) Key")
                    )
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                } header: {
                    HStack {
                        Text("Name")
                        Text("*").foregroundStyle(theme.error)
                    }
                }
                
                // API Key (for providers that need it)
                if !viewModel.showBaseUrlField || viewModel.selectedProvider == .custom {
                    Section {
                        HStack {
                            SecureField(
                                "API Key",
                                text: $viewModel.apiKey,
                                prompt: Text(viewModel.selectedProvider.apiKeyPlaceholder.isEmpty ? "Enter API key" : viewModel.selectedProvider.apiKeyPlaceholder)
                            )
                            .textContentType(.password)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .apiKey)
                        }
                    } header: {
                        HStack {
                            Text("API Key")
                            if !isLocalProvider {
                                Text("*").foregroundStyle(theme.error)
                            }
                        }
                    } footer: {
                        if let url = viewModel.selectedProvider.websiteURL {
                            Button {
                                openURL(url)
                            } label: {
                                Label("Get your API key", systemImage: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Organization ID (OpenAI only)
                if viewModel.showOrgIdField {
                    Section {
                        TextField(
                            "Organization ID",
                            text: $viewModel.orgId,
                            prompt: Text("org-... (optional)")
                        )
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .orgId)
                    } header: {
                        Text("Organization")
                    } footer: {
                        Text("Optional. Only needed if you belong to multiple organizations.")
                    }
                }
                
                // Base URL (for local/custom providers)
                if viewModel.showBaseUrlField {
                    Section {
                        TextField(
                            "Base URL",
                            text: $viewModel.baseUrl,
                            prompt: Text(viewModel.selectedProvider.baseURL)
                        )
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .baseUrl)
                    } header: {
                        HStack {
                            Text("Server URL")
                            Text("*").foregroundStyle(theme.error)
                        }
                    } footer: {
                        if viewModel.selectedProvider == .ollama {
                            Text("Default: http://localhost:11434")
                        } else if viewModel.selectedProvider == .lmstudio {
                            Text("Default: http://localhost:1234/v1")
                        }
                    }
                }
                
                // Data sharing disclosure
                if !isLocalProvider {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("Third-Party Data Sharing")
                                    .font(.subheadline.bold())
                            } icon: {
                                OneraIcon.shieldAlert.image
                                    .foregroundStyle(.orange)
                            }
                            
                            Text("When you use this connection, your chat messages and prompts are sent directly from your device to **\(viewModel.selectedProvider.displayName)**. Onera does not process or store your conversations on our servers.")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                            
                            Text("Data sent to the provider is subject to their privacy policy and terms of service.")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Security note
                Section {
                    Label {
                        Text("Your credentials are encrypted with your E2EE key and stored securely. They are never visible to the server.")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    } icon: {
                        OneraIcon.shield.solidImage
                            .foregroundStyle(theme.success)
                    }
                }
            }
            .navigationTitle("Add Connection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !isLocalProvider && !hasAcknowledgedAIDataSharing {
                            showDataSharingDisclosure = true
                        } else {
                            performSave()
                        }
                    }
                    .disabled(!canSave || viewModel.isSaving)
                }
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    theme.textPrimary.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.lg, style: .continuous))
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .alert("Third-Party Data Sharing", isPresented: $showDataSharingDisclosure) {
                Button("I Agree") {
                    hasAcknowledgedAIDataSharing = true
                    performSave()
                }
                Button("View Privacy Policy") {
                    openURL(URL(string: "https://onera.chat/privacy")!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("By connecting to \(viewModel.selectedProvider.displayName), your chat messages and prompts will be sent directly from your device to their servers using your API key. Onera does not intercept, store, or process this data.\n\nYour use of third-party AI services is subject to their respective privacy policies and terms.")
            }
            .onAppear {
                // Set provider if passed in
                if let provider = selectedProvider {
                    viewModel.selectedProvider = provider
                }
                // Set default base URL for local providers
                if viewModel.showBaseUrlField && viewModel.baseUrl.isEmpty {
                    viewModel.baseUrl = viewModel.selectedProvider.baseURL
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performSave() {
        Task {
            if await viewModel.saveCredential() {
                if let onSave = onSave {
                    onSave()
                } else {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isLocalProvider: Bool {
        viewModel.selectedProvider == .ollama || viewModel.selectedProvider == .lmstudio
    }
    
    private var canSave: Bool {
        if viewModel.credentialName.isEmpty {
            return false
        }
        
        if isLocalProvider {
            return !viewModel.baseUrl.isEmpty
        }
        
        return !viewModel.apiKey.isEmpty
    }
    
    // MARK: - Helpers
    
    private func descriptionForProvider(_ provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "GPT-4, GPT-4o, o1, and more"
        case .anthropic: return "Claude 4, Claude 3.7 Sonnet"
        case .google: return "Gemini 2.0, Gemini 1.5"
        case .xai: return "Grok 2, Grok 3"
        case .groq: return "Ultra-fast inference"
        case .mistral: return "Mistral Large, Codestral"
        case .deepseek: return "DeepSeek V3, DeepSeek-R1"
        case .openrouter: return "200+ models from multiple providers"
        case .together: return "Open source models"
        case .fireworks: return "Fast inference"
        case .ollama: return "Run models locally"
        case .lmstudio: return "Local LM Studio server"
        case .custom: return "OpenAI-compatible endpoint"
        case .private: return "End-to-end encrypted inference"
        }
    }
    
    private func iconForProvider(_ provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .google: return "g.circle.fill"
        case .xai: return "x.circle.fill"
        case .groq: return "bolt.fill"
        case .mistral: return "wind"
        case .deepseek: return "magnifyingglass"
        case .openrouter: return "arrow.triangle.branch"
        case .together: return "person.2.fill"
        case .fireworks: return "flame.fill"
        case .ollama: return "desktopcomputer"
        case .lmstudio: return "server.rack"
        case .custom: return "gearshape.fill"
        case .private: return "lock.shield.fill"
        }
    }
    
    private func colorForProvider(_ provider: LLMProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .xai: return Color.primary
        case .groq: return .orange
        case .mistral: return .blue
        case .deepseek: return .purple
        case .openrouter: return .pink
        case .together: return .blue
        case .fireworks: return .orange
        case .ollama: return .green
        case .lmstudio: return .purple
        case .custom: return .gray
        case .private: return .purple
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AddCredentialView(
        viewModel: CredentialsViewModel(
            credentialService: MockCredentialService(),
            networkService: MockNetworkService(),
            cryptoService: CryptoService(),
            extendedCryptoService: CryptoService(),
            secureSession: MockSecureSession(),
            authService: MockAuthService()
        )
    )
}
#endif
