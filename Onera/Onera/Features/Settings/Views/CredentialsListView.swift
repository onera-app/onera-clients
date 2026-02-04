//
//  CredentialsListView.swift
//  Onera
//
//  List view for managing API credentials
//

import SwiftUI

struct CredentialsListView: View {
    
    @Bindable var viewModel: CredentialsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            if viewModel.credentials.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                credentialsList
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("API Connections")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddCredential = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.refreshCredentials()
        }
        .sheet(isPresented: $viewModel.showAddCredential) {
            AddCredentialView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete Connection",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let credential = viewModel.credentialToDelete {
                    Task {
                        await viewModel.deleteCredential(credential)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.credentialToDelete = nil
            }
        } message: {
            if let credential = viewModel.credentialToDelete {
                Text("Are you sure you want to delete '\(credential.name)'? This action cannot be undone.")
            }
        }
        .onAppear {
            viewModel.loadCredentials()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("No API Connections")
                    .font(.headline)
                
                Text("Add your API keys to start using AI models from different providers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    viewModel.showAddCredential = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemGray))
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    // MARK: - Credentials List
    
    private var credentialsList: some View {
        ForEach(viewModel.credentials) { credential in
            CredentialRowView(credential: credential) {
                viewModel.confirmDelete(credential)
            }
        }
    }
}

// MARK: - Credential Row

private struct CredentialRowView: View {
    
    let credential: DecryptedCredential
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Provider Icon
            providerIcon
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(credential.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(credential.provider.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // API Key preview
            Text(maskedApiKey)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var providerIcon: some View {
        ZStack {
            Circle()
                .fill(providerColor.opacity(0.15))
            
            Text(credential.provider.displayName.prefix(1))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(providerColor)
        }
        .frame(width: 36, height: 36)
    }
    
    private var providerColor: Color {
        switch credential.provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .xai: return .purple
        case .groq: return .pink
        case .mistral: return .cyan
        case .deepseek: return .indigo
        case .openrouter: return .teal
        case .together: return .mint
        case .fireworks: return .red
        case .ollama: return .gray
        case .lmstudio: return .gray
        case .custom: return .secondary
        case .private: return .purple
        }
    }
    
    private var maskedApiKey: String {
        let key = credential.apiKey
        if key.count > 8 {
            return String(key.prefix(4)) + "••••" + String(key.suffix(4))
        }
        return "••••••••"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        CredentialsListView(
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
}
#endif
