//
//  SettingsView.swift
//  Onera
//
//  App settings and account management
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    
    var body: some View {
        NavigationStack {
            List {
                accountSection
                securitySection
                devicesSection
                appSection
                signOutSection
                versionSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showRecoveryPhrase) {
                RecoveryPhraseDisplayView(
                    viewModel: viewModel,
                    onDismiss: { viewModel.clearRecoveryPhrase() }
                )
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $viewModel.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out? Make sure you have your recovery phrase saved.")
            }
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }
    
    // MARK: - Sections
    
    private var accountSection: some View {
        Section("Account") {
            if let user = viewModel.user {
                HStack {
                    Circle()
                        .fill(.tint.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Text(user.initials)
                                .font(.title2.bold())
                                .foregroundStyle(.tint)
                        }
                    
                    VStack(alignment: .leading) {
                        Text(user.displayName)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var securitySection: some View {
        Section("Security") {
            HStack {
                Label("End-to-End Encryption", systemImage: "lock.shield.fill")
                Spacer()
                Text(viewModel.isSessionUnlocked ? "Active" : "Locked")
                    .foregroundStyle(viewModel.isSessionUnlocked ? .green : .orange)
            }
            
            Button {
                viewModel.showRecoveryPhrase = true
            } label: {
                Label("View Recovery Phrase", systemImage: "key.fill")
            }
            .disabled(!viewModel.isSessionUnlocked)
            
            if viewModel.isSessionUnlocked {
                Button {
                    Task { await viewModel.lockSession() }
                } label: {
                    Label("Lock Session", systemImage: "lock.fill")
                }
            }
        }
    }
    
    private var devicesSection: some View {
        Section("Devices") {
            NavigationLink {
                DeviceManagementView()
            } label: {
                Label("Manage Devices", systemImage: "laptopcomputer.and.iphone")
            }
        }
    }
    
    private var appSection: some View {
        Section("App") {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            Link(destination: URL(string: "https://onera.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            
            Link(destination: URL(string: "https://onera.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
    
    private var versionSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.fullVersionString)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Recovery Phrase Display

struct RecoveryPhraseDisplayView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingRecoveryPhrase {
                    ProgressView("Decrypting...")
                } else if let phrase = viewModel.recoveryPhrase {
                    phraseView(phrase)
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadRecoveryPhrase()
        }
    }
    
    private func phraseView(_ phrase: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Your Recovery Phrase")
                    .font(.title2.bold())
                
                RecoveryPhraseGrid(phrase: phrase)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Button {
                    UIPasteboard.general.string = phrase
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text("Keep this phrase secure. Never share it with anyone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView(
            "Unable to Load",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
}

// MARK: - Device Management

struct DeviceManagementView: View {
    var body: some View {
        List {
            Section("Current Device") {
                HStack {
                    Image(systemName: "iphone")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(UIDevice.current.name)
                            .font(.headline)
                        Text("This device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Other Devices") {
                Text("No other devices")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Devices")
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    
    @AppStorage("colorScheme") private var colorScheme = 0
    
    var body: some View {
        List {
            Picker("Theme", selection: $colorScheme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            secureSession: MockSecureSession(),
            onSignOut: {}
        )
    )
}
