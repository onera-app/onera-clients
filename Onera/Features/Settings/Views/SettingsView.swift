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
    @AppStorage("colorScheme") private var selectedColorScheme = 0
    
    private var preferredScheme: ColorScheme? {
        switch selectedColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                profileHeaderSection
                accountSection
                securitySection
                appSection
                aboutSection
                logOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
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
        .preferredColorScheme(preferredScheme)
        .onAppear {
            viewModel.loadSettings()
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 16) {
                // Large Avatar
                if let user = viewModel.user {
                    ZStack {
                        if let imageURL = user.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray4)
                            }
                        } else {
                            Color(.systemGray4)
                            Text(user.initials)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    
                    // Display Name
                    Text(user.displayName)
                        .font(.title2.bold())
                    
                    // Username/Email
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Edit Profile Button
                    Button {
                        // Edit profile action
                    } label: {
                        Text("Edit profile")
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                } else {
                    // No user state
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                    
                    Text("Not signed in")
                        .font(.title2.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            if let user = viewModel.user {
                HStack {
                    Label("Email", systemImage: "envelope")
                    Spacer()
                    Text(user.email)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Security Section
    
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
                HStack {
                    Label("View Recovery Phrase", systemImage: "key.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!viewModel.isSessionUnlocked)
            .accessibilityIdentifier("recoveryPhraseButton")
            
            if viewModel.isSessionUnlocked {
                Button {
                    Task { await viewModel.lockSession() }
                } label: {
                    HStack {
                        Label("Lock Session", systemImage: "lock.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            NavigationLink {
                DeviceManagementView()
            } label: {
                Label("Manage Devices", systemImage: "laptopcomputer.and.iphone")
            }
            
            NavigationLink {
                CredentialsListView(viewModel: viewModel.credentialsViewModel)
            } label: {
                Label("API Connections", systemImage: "key.horizontal")
            }
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        Section("App") {
            Picker(selection: $selectedColorScheme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            } label: {
                Label("Appearance", systemImage: "sun.max")
            }
            .accessibilityIdentifier("themeSelector")
            
            Link(destination: URL(string: "https://onera.app/privacy")!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://onera.app/terms")!) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var appearanceText: String {
        switch selectedColorScheme {
        case 1: return "Light"
        case 2: return "Dark"
        default: return "System"
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("About") {
            Link(destination: URL(string: "https://onera.app/help")!) {
                HStack {
                    Label("Help Center", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.fullVersionString)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Log Out Section
    
    private var logOutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showSignOutConfirmation = true
            } label: {
                HStack {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
            .accessibilityIdentifier("signOutButton")
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
            credentialService: MockCredentialService(),
            networkService: MockNetworkService(),
            cryptoService: CryptoService(),
            onSignOut: {}
        )
    )
}
