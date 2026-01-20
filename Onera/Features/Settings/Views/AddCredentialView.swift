//
//  AddCredentialView.swift
//  Onera
//
//  Form to add a new API credential
//

import SwiftUI

struct AddCredentialView: View {
    
    @Bindable var viewModel: CredentialsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name, apiKey, baseUrl, orgId
    }
    
    var body: some View {
        NavigationStack {
            Form {
                providerSection
                detailsSection
                
                if viewModel.showOrgIdField {
                    organizationSection
                }
                
                if viewModel.showBaseUrlField {
                    customUrlSection
                }
            }
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.saveCredential() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
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
        }
    }
    
    // MARK: - Provider Section
    
    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(viewModel.providerGroups, id: \.0) { group, providers in
                    Section(header: Text(group)) {
                        ForEach(providers, id: \.self) { provider in
                            Label {
                                Text(provider.displayName)
                            } icon: {
                                Image(systemName: iconForProvider(provider))
                            }
                            .tag(provider)
                        }
                    }
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Provider")
        } footer: {
            Text(providerDescription)
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section {
            TextField("Name", text: $viewModel.credentialName, prompt: Text("My \(viewModel.selectedProvider.displayName) Key"))
                .textContentType(.name)
                .focused($focusedField, equals: .name)
            
            SecureField("API Key", text: $viewModel.apiKey, prompt: Text("sk-..."))
                .textContentType(.password)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .apiKey)
        } header: {
            Text("Details")
        } footer: {
            Text("Your API key is encrypted locally before being stored.")
        }
    }
    
    // MARK: - Organization Section (OpenAI)
    
    private var organizationSection: some View {
        Section {
            TextField("Organization ID", text: $viewModel.orgId, prompt: Text("org-... (optional)"))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .orgId)
        } header: {
            Text("Organization")
        } footer: {
            Text("Optional. Required if you belong to multiple OpenAI organizations.")
        }
    }
    
    // MARK: - Custom URL Section
    
    private var customUrlSection: some View {
        Section {
            TextField("Base URL", text: $viewModel.baseUrl, prompt: Text(viewModel.selectedProvider.baseURL))
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .baseUrl)
        } header: {
            Text("Server URL")
        } footer: {
            if viewModel.selectedProvider == .ollama {
                Text("Default: http://localhost:11434")
            } else if viewModel.selectedProvider == .lmstudio {
                Text("Default: http://localhost:1234/v1")
            } else {
                Text("The base URL for API requests.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var providerDescription: String {
        switch viewModel.selectedProvider {
        case .openai:
            return "GPT-4, GPT-4o, o1, and more from OpenAI."
        case .anthropic:
            return "Claude models from Anthropic."
        case .google:
            return "Gemini models from Google."
        case .xai:
            return "Grok models from xAI."
        case .groq:
            return "Fast inference for open models."
        case .mistral:
            return "Mistral and Mixtral models."
        case .deepseek:
            return "DeepSeek models including DeepSeek-R1."
        case .openrouter:
            return "Access multiple providers through one API."
        case .together:
            return "Open source models from Together."
        case .fireworks:
            return "Fast inference from Fireworks AI."
        case .ollama:
            return "Run models locally with Ollama."
        case .lmstudio:
            return "Run models locally with LM Studio."
        case .custom:
            return "Any OpenAI-compatible API endpoint."
        }
    }
    
    private func iconForProvider(_ provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .google: return "g.circle"
        case .xai: return "x.circle"
        case .groq: return "bolt"
        case .mistral: return "wind"
        case .deepseek: return "magnifyingglass"
        case .openrouter: return "arrow.triangle.branch"
        case .together: return "person.2"
        case .fireworks: return "flame"
        case .ollama: return "desktopcomputer"
        case .lmstudio: return "server.rack"
        case .custom: return "gearshape"
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
            secureSession: MockSecureSession(),
            authService: MockAuthService()
        )
    )
}
#endif
