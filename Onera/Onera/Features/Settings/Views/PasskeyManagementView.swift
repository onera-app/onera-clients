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
    /// Decrypted display names keyed by passkey id
    private(set) var decryptedNames: [String: String] = [:]
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var isRegistering = false
    
    var passkeyName = ""
    
    private let passkeyService: PasskeyServiceProtocol
    private let authService: AuthServiceProtocol
    private let secureSession: SecureSessionProtocol
    private let cryptoService: ExtendedCryptoServiceProtocol
    
    init(passkeyService: PasskeyServiceProtocol, authService: AuthServiceProtocol, secureSession: SecureSessionProtocol, cryptoService: ExtendedCryptoServiceProtocol) {
        self.passkeyService = passkeyService
        self.authService = authService
        self.secureSession = secureSession
        self.cryptoService = cryptoService
    }
    
    /// Get the display name for a passkey (decrypted or fallback)
    func displayName(for passkey: WebAuthnPasskey) -> String {
        decryptedNames[passkey.id] ?? "Passkey"
    }
    
    func loadPasskeys() async {
        isLoading = true
        error = nil
        do {
            let token = try await authService.getToken()
            passkeys = try await passkeyService.listPasskeys(token: token)
            decryptPasskeyNames()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    /// Decrypt all passkey names using the master key
    private func decryptPasskeyNames() {
        guard let masterKey = secureSession.masterKey else { return }
        var names: [String: String] = [:]
        for passkey in passkeys {
            if let encName = passkey.encryptedName, let nonce = passkey.nameNonce {
                do {
                    let name = try cryptoService.decryptString(ciphertext: encName, nonce: nonce, key: masterKey)
                    names[passkey.id] = name
                } catch {
                    names[passkey.id] = "Passkey"
                }
            } else {
                names[passkey.id] = "Passkey"
            }
        }
        decryptedNames = names
    }
    
    func renamePasskey(credentialId: String, newName: String) async {
        guard let masterKey = secureSession.masterKey else {
            error = "Session must be unlocked to rename a passkey"
            return
        }
        do {
            let token = try await authService.getToken()
            let encrypted = try cryptoService.encryptString(newName, key: masterKey)
            try await passkeyService.renamePasskey(
                credentialId: credentialId,
                encryptedName: encrypted.ciphertext,
                nameNonce: encrypted.nonce,
                token: token
            )
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
            Text("Are you sure you want to delete \"\(viewModel.displayName(for: passkey))\"? This action cannot be undone.")
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
                    Text(viewModel.displayName(for: passkey))
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
                    editName = viewModel.displayName(for: passkey)
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
