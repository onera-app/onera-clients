//
//  PasskeyManagementView.swift
//  Onera
//
//  Manages registered passkeys — list, rename, delete, and register new passkeys
//

import SwiftUI

@MainActor
@Observable
final class PasskeyManagementViewModel {
    private(set) var passkeys: [WebAuthnPasskey] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var isRegistering = false
    
    var passkeyName = ""
    
    private let passkeyService: PasskeyServiceProtocol
    private let authService: AuthServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    init(passkeyService: PasskeyServiceProtocol, authService: AuthServiceProtocol, secureSession: SecureSessionProtocol) {
        self.passkeyService = passkeyService
        self.authService = authService
        self.secureSession = secureSession
    }
    
    func loadPasskeys() async {
        isLoading = true
        error = nil
        do {
            let token = try await authService.getToken()
            passkeys = try await passkeyService.listPasskeys(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func renamePasskey(credentialId: String, newName: String) async {
        do {
            let token = try await authService.getToken()
            try await passkeyService.renamePasskey(credentialId: credentialId, name: newName, token: token)
            await loadPasskeys()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deletePasskey(credentialId: String) async {
        do {
            let token = try await authService.getToken()
            try await passkeyService.deletePasskey(credentialId: credentialId, token: token)
            await loadPasskeys()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func registerPasskey() async {
        guard let masterKey = secureSession.masterKey else {
            error = "Session must be unlocked to register a passkey"
            return
        }
        
        isRegistering = true
        error = nil
        do {
            let token = try await authService.getToken()
            let name = passkeyName.isEmpty ? nil : passkeyName
            _ = try await passkeyService.registerPasskey(masterKey: masterKey, name: name, token: token)
            passkeyName = ""
            await loadPasskeys()
        } catch {
            self.error = error.localizedDescription
        }
        isRegistering = false
    }
    
    var isSupported: Bool {
        passkeyService.isPasskeySupported()
    }
}

struct PasskeyManagementView: View {
    @Bindable var viewModel: PasskeyManagementViewModel
    @Environment(\.theme) private var theme
    
    @State private var editingPasskeyId: String?
    @State private var editName = ""
    @State private var showDeleteConfirmation = false
    @State private var passkeyToDelete: WebAuthnPasskey?
    @State private var showRegisterSheet = false
    
    var body: some View {
        List {
            if let error = viewModel.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            
            if !viewModel.isSupported {
                Section {
                    Label("Passkeys are not supported on this device", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Registered Passkeys") {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.passkeys.isEmpty {
                    Text("No passkeys registered")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.passkeys) { passkey in
                        passkeyRow(passkey)
                    }
                }
            }
            
            if viewModel.isSupported {
                Section {
                    Button {
                        showRegisterSheet = true
                    } label: {
                        Label("Register New Passkey", systemImage: "plus.circle")
                    }
                    .disabled(viewModel.isRegistering)
                }
            }
        }
        .navigationTitle("Passkeys")
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
        .task {
            await viewModel.loadPasskeys()
        }
        .confirmationDialog(
            "Delete Passkey",
            isPresented: $showDeleteConfirmation,
            presenting: passkeyToDelete
        ) { passkey in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePasskey(credentialId: passkey.credentialId) }
            }
        } message: { passkey in
            Text("Are you sure you want to delete \"\(passkey.name ?? "this passkey")\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showRegisterSheet) {
            registerSheet
        }
    }
    
    // MARK: - Passkey Row
    
    @ViewBuilder
    private func passkeyRow(_ passkey: WebAuthnPasskey) -> some View {
        if editingPasskeyId == passkey.id {
            // Inline rename
            HStack {
                TextField("Passkey name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.renamePasskey(credentialId: passkey.credentialId, newName: editName)
                            editingPasskeyId = nil
                        }
                    }
                
                Button {
                    Task {
                        await viewModel.renamePasskey(credentialId: passkey.credentialId, newName: editName)
                        editingPasskeyId = nil
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                
                Button {
                    editingPasskeyId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack {
                Image(systemName: passkey.credentialDeviceType == "multiDevice" ? "icloud" : "iphone")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(passkey.name ?? "Unnamed Passkey")
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        if passkey.credentialBackedUp == true {
                            Text("Synced")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        
                        Text("Created \(passkey.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        if let lastUsed = passkey.lastUsedAt {
                            Text("Used \(lastUsed.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .contextMenu {
                Button {
                    editName = passkey.name ?? ""
                    editingPasskeyId = passkey.id
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    passkeyToDelete = passkey
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    passkeyToDelete = passkey
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Register Sheet
    
    private var registerSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.key.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            
            Text("Register New Passkey")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("A passkey lets you unlock your encryption keys using Face ID, Touch ID, or your device passcode. Synced passkeys work across your Apple devices.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Passkey name (optional)", text: $viewModel.passkeyName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showRegisterSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button {
                    Task {
                        await viewModel.registerPasskey()
                        if viewModel.error == nil {
                            showRegisterSheet = false
                        }
                    }
                } label: {
                    if viewModel.isRegistering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Register")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isRegistering)
            }
            
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
