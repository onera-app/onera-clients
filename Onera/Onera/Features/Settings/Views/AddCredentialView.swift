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
    @FocusState private var focusedField: Field?
    
    /// Optional: Pre-select a provider (for use from onboarding)
    var selectedProvider: LLMProvider?
    /// Optional: Callback when credential is saved
    var onSave: (() -> Void)?
    /// Optional: Callback when cancelled
    var onCancel: (() -> Void)?
    
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
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedProvider.displayName)
                                .font(.headline)
                            Text(descriptionForProvider(viewModel.selectedProvider))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let url = viewModel.selectedProvider.websiteURL {
                            Button {
                                openURL(url)
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.blue)
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
                        Text("*").foregroundStyle(.red)
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
                                Text("*").foregroundStyle(.red)
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
                            Text("*").foregroundStyle(.red)
                        }
                    } footer: {
                        if viewModel.selectedProvider == .ollama {
                            Text("Default: http://localhost:11434")
                        } else if viewModel.selectedProvider == .lmstudio {
                            Text("Default: http://localhost:1234/v1")
                        }
                    }
                }
                
                // Security note
                Section {
                    Label {
                        Text("Your credentials are encrypted with your E2EE key and stored securely. They are never visible to the server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
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
                    .disabled(!canSave || viewModel.isSaving)
                }
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
